import Foundation
import JingshanCore

@MainActor
@Observable
final class LargeFilesViewModel {
    private(set) var candidates: [LargeFileScanner.Candidate] = []
    private(set) var isScanning = false
    private(set) var isCleaning = false
    private(set) var hasScannedOnce = false
    private(set) var scanningPath: String?
    private(set) var liveFoundCount = 0
    var selectedIDs: Set<String> = []
    var lastCleanupSummary: CleanupSummary?

    /// The folder to scan. Defaults to the home directory; the user can point
    /// it at a specific folder instead.
    var scanRoot: String = LargeFileScanner.defaultRoot()

    private var scanTask: Task<Void, Never>?

    var totalBytes: Int64 { candidates.reduce(0) { $0 + $1.sizeBytes } }
    var oldCount: Int { candidates.filter(\.isOld).count }

    var selectedCandidates: [LargeFileScanner.Candidate] {
        candidates.filter { selectedIDs.contains($0.id) }
    }
    var totalSelectedBytes: Int64 {
        selectedCandidates.reduce(0) { $0 + $1.sizeBytes }
    }

    func startScan() {
        guard !isCleaning else { return }
        scanTask?.cancel()
        candidates = []
        selectedIDs = []
        lastCleanupSummary = nil
        scanningPath = nil
        liveFoundCount = 0
        isScanning = true

        let root = scanRoot
        scanTask = Task {
            let scanner = LargeFileScanner()
            let found = await scanner.scan(root: root) { progress in
                Task { @MainActor in
                    guard self.isScanning else { return }
                    self.scanningPath = progress.currentPath
                    self.liveFoundCount = progress.foundCount
                }
            }
            guard !Task.isCancelled else { return }
            self.candidates = found
            // Deleting a user's own large files is high-stakes, so NOTHING is
            // pre-selected — every file must be ticked by hand.
            self.selectedIDs = []
            self.scanningPath = nil
            self.isScanning = false
            self.hasScannedOnce = true
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanningPath = nil
        isScanning = false
    }

    func isSelected(_ candidate: LargeFileScanner.Candidate) -> Bool {
        selectedIDs.contains(candidate.id)
    }

    func setSelected(_ candidate: LargeFileScanner.Candidate, _ selected: Bool) {
        if selected { selectedIDs.insert(candidate.id) } else { selectedIDs.remove(candidate.id) }
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
        var trashed: [TrashedItem] = []

        for candidate in selectedCandidates {
            let outcome = engine.delete(path: candidate.path, mode: mode)
            switch outcome {
            case .movedToTrash(_, let resultingURL, let size):
                freed += size ?? 0
                deleted += 1
                if let resultingURL {
                    trashed.append(TrashedItem(originalPath: candidate.path, trashPath: resultingURL.path))
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

        lastCleanupSummary = CleanupSummary(freedBytes: freed, deletedCount: deleted, skippedCount: skipped, failedCount: failed, dryRun: isDryRun)
        if !isDryRun {
            CleanupHistoryStore.shared.record(module: "大文件", freedBytes: freed, itemCount: deleted, trashedItems: trashed)
        }
        selectedIDs = []
        startScan()
    }
}
