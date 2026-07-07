import Foundation
import JingshanCore

@MainActor
@Observable
final class UninstallerViewModel {
    private(set) var installedApps: [InstalledApplication] = []
    private(set) var isScanningApps = false
    private(set) var isScanningResiduals = false
    private(set) var isUninstalling = false

    private(set) var selectedApp: InstalledApplication?
    private(set) var residualCandidates: [ResidualCandidate] = []
    var selectedResidualIDs: Set<String> = []
    var lastUninstallSummary: CleanupSummary?

    private let appScanner = InstalledApplicationScanner()
    private let residualScanner = ResidualFileScanner()
    private let protectionEvaluator = ProtectionEvaluator()

    private var appScanTask: Task<Void, Never>?
    private var residualScanTask: Task<Void, Never>?

    /// Live verdict for the currently selected app — re-evaluated on every
    /// read, since "is it running" can change between scan and click. This
    /// drives the UI's disabled state; the actual safety backstop is the
    /// identical check `DeletionEngine` performs again at delete time.
    var selectedAppProtectionVerdict: ProtectionEvaluator.Verdict? {
        guard let selectedApp else { return nil }
        return protectionEvaluator.evaluate(bundleIdentifier: selectedApp.bundleIdentifier)
    }

    var canUninstallSelectedApp: Bool {
        guard !isScanningResiduals, !isUninstalling else { return false }
        if case .notProtected = selectedAppProtectionVerdict { return true }
        return false
    }

    var hasDestructiveSelection: Bool {
        residualCandidates.contains { $0.tier == .destructive && selectedResidualIDs.contains($0.id) }
    }

    var totalSelectedBytes: Int64 {
        let appSize = selectedApp?.sizeBytes ?? 0
        let residualSize = residualCandidates
            .filter { selectedResidualIDs.contains($0.id) }
            .reduce(Int64(0)) { $0 + ($1.sizeBytes ?? 0) }
        return appSize + residualSize
    }

    var selectedItemCount: Int {
        (selectedApp == nil ? 0 : 1) + selectedResidualIDs.count
    }

    func startScan() {
        guard !isUninstalling else { return }
        appScanTask?.cancel()
        installedApps = []
        isScanningApps = true

        appScanTask = Task {
            let roots = InstalledApplicationScanner.defaultRoots()
            let found = await appScanner.scan(roots: roots)
            guard !Task.isCancelled else { return }
            installedApps = found.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            isScanningApps = false
        }
    }

    func cancelScan() {
        appScanTask?.cancel()
        isScanningApps = false
    }

    func selectApp(_ app: InstalledApplication) {
        guard app.id != selectedApp?.id else { return }
        residualScanTask?.cancel()
        selectedApp = app
        residualCandidates = []
        selectedResidualIDs = []
        lastUninstallSummary = nil
        isScanningResiduals = true

        residualScanTask = Task {
            let found = await residualScanner.scanResiduals(for: app)
            guard !Task.isCancelled else { return }
            residualCandidates = found.sorted { ($0.sizeBytes ?? 0) > ($1.sizeBytes ?? 0) }
            // Safe/caution residuals default on; destructive (sandbox
            // container data, which can hold real app data rather than
            // mere cache) is never auto-selected.
            selectedResidualIDs = Set(found.filter { $0.tier.isDefaultSelectable }.map(\.id))
            isScanningResiduals = false
        }
    }

    func isResidualSelected(_ candidate: ResidualCandidate) -> Bool {
        selectedResidualIDs.contains(candidate.id)
    }

    func setResidualSelected(_ candidate: ResidualCandidate, _ selected: Bool) {
        if selected {
            selectedResidualIDs.insert(candidate.id)
        } else {
            selectedResidualIDs.remove(candidate.id)
        }
    }

    func performUninstall(permanently: Bool) async {
        guard let app = selectedApp, canUninstallSelectedApp, !isUninstalling else { return }
        isUninstalling = true
        defer { isUninstalling = false }

        let settings = AppSettings.shared
        let engine = settings.makeDeletionEngine()
        let mode = settings.fileDeletionMode(permanent: permanently)
        let isDryRun = settings.dryRunEnabled

        var freed: Int64 = 0
        var deleted = 0
        var skipped = 0
        var failed = 0

        func apply(_ outcome: DeletionOutcome) {
            switch outcome {
            case .movedToTrash(_, _, let size), .permanentlyDeleted(_, let size), .wouldDelete(_, let size):
                freed += size ?? 0
                deleted += 1
            case .alreadyAbsent:
                break
            case .skippedExcluded, .skippedProtectedApp:
                skipped += 1
            case .failed:
                failed += 1
            }
        }

        // Every delete carries the app's bundle identifier so the engine
        // re-checks protection/running state at the moment of the actual
        // filesystem mutation — not just the earlier scan-time check, in
        // case the app was relaunched in between. Never overridable: an
        // uninstall must never force through a live app's own files.
        apply(engine.delete(path: app.path, mode: mode, associatedBundleIdentifier: app.bundleIdentifier))

        // Docker Desktop's sandbox container (~/Library/Containers/com.docker.docker)
        // isn't ordinary leftover data — it holds the entire VM disk backing
        // every image/container/volume (multiple GB on a real machine). The
        // generic destructive-tier checkbox this screen uses has no
        // Docker-specific liveness awareness, unlike Docker's own cleanup
        // module, which refuses to touch that same file unless BOTH the app
        // is not running AND the daemon is unreachable. Mirror that same
        // pair of checks here before letting this one bundle identifier's
        // destructive-tier residuals through, so this generic screen can't
        // become a second, weaker path to the exact danger the Docker
        // module was built to prevent.
        var dockerLikelyLive = false
        if app.bundleIdentifier == "com.docker.docker" {
            dockerLikelyLive = DockerAvailability.isDockerDesktopRunning()
            if !dockerLikelyLive {
                dockerLikelyLive = await DockerAvailability.makeDefault().checkStatus() == .available
            }
        }

        for candidate in residualCandidates where selectedResidualIDs.contains(candidate.id) {
            if candidate.tier == .destructive, dockerLikelyLive {
                skipped += 1
                continue
            }
            apply(engine.delete(path: candidate.path, mode: mode, associatedBundleIdentifier: app.bundleIdentifier))
        }

        lastUninstallSummary = CleanupSummary(freedBytes: freed, deletedCount: deleted, skippedCount: skipped, failedCount: failed, dryRun: isDryRun)
        selectedApp = nil
        residualCandidates = []
        selectedResidualIDs = []
        startScan()
    }
}
