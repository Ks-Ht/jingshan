import Foundation
import JingshanCore

enum DockerDaemonState: Equatable {
    case checking
    case notInstalled
    case daemonNotRunning
    case available
}

struct DockerCleanupSummary: Equatable {
    let freedBytes: Int64
    let removedCount: Int
    let failedCount: Int
    var dryRun: Bool = false
}

/// Removal order: remove containers before the images they reference, and
/// leave the whole-store VM disk for last. An image still referenced by a
/// stopped container can't be removed until that container is gone.
/// Networks come right after containers too, since a container still
/// attached to a custom network keeps it out of `docker network prune`'s
/// "unused" set.
private func removalPriority(_ kind: DockerResourceKind) -> Int {
    switch kind {
    case .container: return 0
    case .network: return 1
    case .buildCache: return 2
    case .image: return 3
    case .volume: return 4
    case .appLog: return 5
    case .appCache: return 6
    case .diskImage: return 7
    }
}

@MainActor
@Observable
final class DockerViewModel {
    private(set) var daemonState: DockerDaemonState = .checking
    /// Host-side data (VM disk, logs, caches) — available with Docker stopped.
    private(set) var hostItems: [DockerCleanableItem] = []
    /// Daemon-side resources (containers, images, build cache, volumes).
    private(set) var runtimeItems: [DockerCleanableItem] = []
    private(set) var isScanning = false
    private(set) var isCleaning = false
    /// Distinguishes "never scanned" from "scanned and genuinely found
    /// nothing" — empty `hostItems`/`runtimeItems` means either.
    private(set) var hasScannedOnce = false
    private(set) var isStartingDocker = false
    private(set) var dockerDesktopRunning = false
    var selectedItemIDs: Set<String> = []
    var lastCleanupSummary: DockerCleanupSummary?

    private var scanTask: Task<Void, Never>?

    private var allItems: [DockerCleanableItem] { hostItems + runtimeItems }

    var selectedItems: [DockerCleanableItem] {
        allItems.filter { selectedItemIDs.contains($0.id) }
    }

    var totalSelectedBytes: Int64 {
        selectedItems.reduce(0) { $0 + ($1.sizeBytes ?? 0) }
    }

    var hostTotalBytes: Int64 { hostItems.reduce(0) { $0 + ($1.sizeBytes ?? 0) } }
    var runtimeTotalBytes: Int64 { runtimeItems.reduce(0) { $0 + ($1.sizeBytes ?? 0) } }

    var hasDestructiveSelection: Bool {
        selectedItems.contains { $0.risk == .destructive }
    }

    /// Host items grouped by kind for display (VM disk / logs / caches).
    var hostItemsByKind: [(kind: DockerResourceKind, items: [DockerCleanableItem])] {
        groupByKind(hostItems)
    }

    /// Runtime items grouped by kind (containers / images / build cache / volumes).
    var runtimeItemsByKind: [(kind: DockerResourceKind, items: [DockerCleanableItem])] {
        groupByKind(runtimeItems)
    }

    private func groupByKind(_ source: [DockerCleanableItem]) -> [(kind: DockerResourceKind, items: [DockerCleanableItem])] {
        DockerResourceKind.allCases.compactMap { kind in
            let matching = source.filter { $0.kind == kind }
            guard !matching.isEmpty else { return nil }
            return (kind, matching.sorted { ($0.sizeBytes ?? 0) > ($1.sizeBytes ?? 0) })
        }
    }

    /// Scans both host-side data (always, works with Docker stopped) and,
    /// when the daemon is up, the runtime resources. Preserves the caller's
    /// intent that host cleanup never needs Docker running.
    func refresh() {
        guard !isCleaning else { return }
        scanTask?.cancel()
        isScanning = true
        selectedItemIDs = []
        lastCleanupSummary = nil

        scanTask = Task {
            let availability = DockerAvailability.makeDefault()
            let installed = availability.isInstalled
            let status = await availability.checkStatus()
            let desktopRunning = DockerAvailability.isDockerDesktopRunning()
            guard !Task.isCancelled else { return }

            dockerDesktopRunning = desktopRunning
            if !installed {
                daemonState = .notInstalled
            } else {
                daemonState = (status == .available) ? .available : .daemonNotRunning
            }

            let hostScanner = DockerHostDataScanner(dockerDesktopRunning: desktopRunning)
            let scannedHost = await hostScanner.scan()

            var scannedRuntime: [DockerCleanableItem] = []
            if status == .available, let path = DockerCLI.locate() {
                let runtimeScanner = DockerResourceScanner(commandRunner: DockerCLI(executablePath: path))
                scannedRuntime = await runtimeScanner.scanAll()
            }
            guard !Task.isCancelled else { return }

            hostItems = scannedHost
            runtimeItems = scannedRuntime
            // Only ever pre-check what the scanners themselves marked safe
            // to pre-check — never widen this here.
            selectedItemIDs = Set((scannedHost + scannedRuntime).filter(\.defaultSelected).map(\.id))
            isScanning = false
            hasScannedOnce = true
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        isScanning = false
    }

    /// Launches Docker Desktop and waits for the daemon to come up, then
    /// re-scans so runtime resources appear.
    func startDockerDesktop() async {
        guard !isStartingDocker else { return }
        isStartingDocker = true
        defer { isStartingDocker = false }

        guard DockerAvailability.launchDockerDesktop() else { return }
        for _ in 0..<20 {
            try? await Task.sleep(for: .seconds(2))
            if await DockerAvailability.makeDefault().checkStatus() == .available { break }
        }
        refresh()
    }

    func isSelected(_ item: DockerCleanableItem) -> Bool {
        selectedItemIDs.contains(item.id)
    }

    func setSelected(_ item: DockerCleanableItem, _ selected: Bool) {
        if selected {
            selectedItemIDs.insert(item.id)
        } else {
            selectedItemIDs.remove(item.id)
        }
    }

    func setSelected(_ items: [DockerCleanableItem], _ selected: Bool) {
        for item in items {
            setSelected(item, selected)
        }
    }

    func performCleanup() async {
        guard !selectedItems.isEmpty, !isScanning, !isCleaning else { return }
        isCleaning = true
        defer { isCleaning = false }

        let settings = AppSettings.shared
        let commandRunner: DockerCommandRunning = DockerCLI.locate().map { DockerCLI(executablePath: $0) } ?? UnavailableDockerRunner()
        // Host-file removals go through the same exclusion-aware DeletionEngine
        // the Clean flow uses; the global dry-run toggle applies here too.
        let engine = DockerCleanupEngine(commandRunner: commandRunner, deletionEngine: settings.makeDeletionEngine())
        let mode = settings.dockerCleanupMode

        var freed: Int64 = 0
        var removed = 0
        var failed = 0

        // Safety re-check for the single most destructive action: the VM
        // disk is only offered when Docker is quit, but the user could have
        // started it between the scan and now. Deleting the disk while its
        // VM is live would corrupt it. Refuse unless BOTH the app is not
        // running AND the daemon is unreachable — belt-and-suspenders, since
        // the app-running check alone could miss a bundle-id variant.
        var dockerActiveNow = DockerAvailability.isDockerDesktopRunning()
        if !dockerActiveNow, selectedItems.contains(where: { $0.kind == .diskImage }) {
            if await DockerAvailability.makeDefault().checkStatus() == .available {
                dockerActiveNow = true
            }
        }

        let ordered = selectedItems.sorted { removalPriority($0.kind) < removalPriority($1.kind) }
        for item in ordered {
            if item.kind == .diskImage && dockerActiveNow {
                failed += 1
                continue
            }
            let outcome = await engine.remove(item, mode: mode)
            switch outcome {
            case .removed(_, let freedBytes):
                freed += freedBytes ?? 0
                removed += 1
            case .wouldRemove(let item):
                // Dry-run preview.
                freed += item.sizeBytes ?? 0
                removed += 1
            case .failed:
                failed += 1
            }
        }

        lastCleanupSummary = DockerCleanupSummary(freedBytes: freed, removedCount: removed, failedCount: failed, dryRun: mode == .dryRun)
        selectedItemIDs.removeAll()
        refresh()
    }
}

/// Stand-in command runner used only when the docker CLI is absent. In that
/// state there are no runtime (`.dockerCommand`) items to remove anyway
/// (they are only produced when the daemon is up), so this never actually
/// runs — it exists so the engine's non-optional runner is satisfiable.
private struct UnavailableDockerRunner: DockerCommandRunning {
    func run(_ arguments: [String], timeout: TimeInterval) async throws -> String {
        throw DockerCommandError.launchFailed(description: "docker CLI unavailable")
    }
}
