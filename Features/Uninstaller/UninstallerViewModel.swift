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

        let settings = AppSettings.shared
        let engine = settings.makeDeletionEngine()
        let mode = settings.fileDeletionMode(permanent: permanently)
        let isDryRun = settings.dryRunEnabled

        var freed: Int64 = 0
        var deleted = 0
        var skipped = 0
        var failed = 0
        var trashed: [TrashedItem] = []

        func apply(_ outcome: DeletionOutcome, originalPath: String) {
            switch outcome {
            case .movedToTrash(_, let resultingURL, let size):
                freed += size ?? 0
                deleted += 1
                if let resultingURL {
                    trashed.append(TrashedItem(originalPath: originalPath, trashPath: resultingURL.path))
                }
            case .permanentlyDeleted(_, let size), .wouldDelete(_, let size):
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
        apply(engine.delete(path: app.path, mode: mode, associatedBundleIdentifier: app.bundleIdentifier, precomputedSizeBytes: app.sizeBytes), originalPath: app.path)

        // Docker Desktop's sandbox container holds the VM disk backing every
        // image/container/volume. Use the same checker as Docker cleanup and
        // run it for each destructive residual immediately before deletion;
        // a single result cached before the loop leaves a wider restart race.
        let dockerDiskSafetyChecker: DockerDiskSafetyChecking? = if app.bundleIdentifier == "com.docker.docker" {
            DockerCLI.locate().map { DefaultDockerDiskSafetyChecker(commandRunner: DockerCLI(executablePath: $0)) }
                ?? DefaultDockerDiskSafetyChecker(commandRunner: nil)
        } else {
            nil
        }

        for candidate in residualCandidates where selectedResidualIDs.contains(candidate.id) {
            if candidate.tier == .destructive, !isDryRun, let dockerDiskSafetyChecker {
                guard await dockerDiskSafetyChecker.isSafeToRemoveDiskImage() else {
                    skipped += 1
                    continue
                }
            }
            apply(engine.delete(path: candidate.path, mode: mode, associatedBundleIdentifier: app.bundleIdentifier, precomputedSizeBytes: candidate.sizeBytes), originalPath: candidate.path)
        }

        let summary = CleanupSummary(freedBytes: freed, deletedCount: deleted, skippedCount: skipped, failedCount: failed, dryRun: isDryRun)
        if !isDryRun {
            CleanupHistoryStore.shared.record(module: "卸载应用", freedBytes: freed, itemCount: deleted, trashedItems: trashed)
        }
        selectedApp = nil
        residualCandidates = []
        selectedResidualIDs = []
        // Un-block BEFORE the rescan (whose `!isUninstalling` guard used to
        // no-op, leaving the just-uninstalled app in the list), and attach
        // the summary AFTER startScan()'s reset so the alert still shows.
        isUninstalling = false
        startScan()
        lastUninstallSummary = summary
    }
}
