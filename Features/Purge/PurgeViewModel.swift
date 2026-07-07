import Foundation
import JingshanCore

@MainActor
@Observable
final class PurgeViewModel {
    private(set) var candidates: [PurgeCandidate] = []
    private(set) var isScanning = false
    private(set) var isCleaning = false
    /// Distinguishes "never scanned" from "scanned and genuinely found
    /// nothing" — an empty `candidates` array means either.
    private(set) var hasScannedOnce = false
    var selectedIDs: Set<String> = []
    var lastCleanupSummary: CleanupSummary?

    private var scanTask: Task<Void, Never>?

    var totalReclaimableBytes: Int64 {
        candidates.reduce(0) { $0 + ($1.sizeBytes ?? 0) }
    }

    var selectedCandidates: [PurgeCandidate] {
        candidates.filter { selectedIDs.contains($0.id) }
    }

    var totalSelectedBytes: Int64 {
        selectedCandidates.reduce(0) { $0 + ($1.sizeBytes ?? 0) }
    }

    var scanRoots: [String] {
        AppSettings.shared.effectivePurgeScanPaths()
    }

    func startScan() {
        guard !isCleaning else { return }
        scanTask?.cancel()
        candidates = []
        selectedIDs = []
        lastCleanupSummary = nil
        isScanning = true

        let roots = scanRoots
        scanTask = Task {
            let scanner = PurgeScanner()
            let found = await scanner.scan(roots: roots)
            guard !Task.isCancelled else { return }
            candidates = found.sorted { ($0.sizeBytes ?? 0) > ($1.sizeBytes ?? 0) }
            // Recently-touched projects default OFF: an actively worked-on
            // project's build artifacts are a less clear-cut win to nuke
            // right now (Mole's own "Recent" projects follow the same
            // unselected-by-default policy).
            selectedIDs = Set(found.filter { !$0.isRecent }.map(\.id))
            isScanning = false
            hasScannedOnce = true
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        isScanning = false
    }

    func isSelected(_ candidate: PurgeCandidate) -> Bool {
        selectedIDs.contains(candidate.id)
    }

    func setSelected(_ candidate: PurgeCandidate, _ selected: Bool) {
        if selected {
            selectedIDs.insert(candidate.id)
        } else {
            selectedIDs.remove(candidate.id)
        }
    }

    func performCleanup(permanently: Bool) async {
        guard !selectedCandidates.isEmpty, !isScanning, !isCleaning else { return }
        isCleaning = true
        defer { isCleaning = false }

        let settings = AppSettings.shared
        let engine = settings.makeDeletionEngine()
        let mode = settings.fileDeletionMode(permanent: permanently)
        let isDryRun = settings.dryRunEnabled

        var freed: Int64 = 0
        var deleted = 0
        var skipped = 0
        var failed = 0

        for candidate in selectedCandidates {
            let outcome = engine.delete(path: candidate.path, mode: mode)
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

        lastCleanupSummary = CleanupSummary(freedBytes: freed, deletedCount: deleted, skippedCount: skipped, failedCount: failed, dryRun: isDryRun)
        selectedIDs.removeAll()
        startScan()
    }
}
