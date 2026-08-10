import Foundation
import JingshanCore

struct CleanupSummary: Equatable {
    let freedBytes: Int64
    let deletedCount: Int
    let skippedCount: Int
    let failedCount: Int
    var dryRun: Bool = false
}

/// An item re-labeled and re-grouped for display, independent of which
/// scanner originally found it.
struct ClassifiedItem: Identifiable {
    let item: ScannableItem
    let displayName: String
    var id: String { item.id }
}

/// One real-world group of cleanup candidates as shown in the UI (e.g.
/// "开发工具"), pooling items from every scanner that produced anything
/// belonging to that group.
struct CleanDisplayGroup: Identifiable {
    let group: CacheGroup
    var items: [ClassifiedItem]
    var id: String { group.rawValue }
    var totalBytes: Int64 {
        items.reduce(0) { $0 + ($1.item.sizeBytes ?? 0) }
    }
}

enum CleanListFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case selected = "已选择"
    case review = "需检查"
    case protected = "已保护"

    var id: Self { self }
}

@MainActor
@Observable
final class CleanViewModel {
    /// The Trash category is handled by its own dedicated "empty Trash"
    /// action, not the generic multi-select cleanup flow — moving
    /// `~/.Trash` itself "to Trash" makes no sense, so it is excluded from
    /// `selectedItemIDs` and rendered as its own row in the UI.
    static let trashCategoryID = "trash"

    private(set) var categories: [ScanCategory] = []
    private(set) var isScanning = false
    private(set) var isCleaning = false
    /// Distinguishes "never scanned" from "scanned and genuinely found
    /// nothing" — an empty `categories` array means either, so the header
    /// needs this to know whether "0 GB" is a real result or just unscanned.
    private(set) var hasScannedOnce = false
    var selectedItemIDs: Set<String> = []
    var lastCleanupSummary: CleanupSummary?
    var query = ""
    var listFilter: CleanListFilter = .all

    /// Strong ("强力") mode: scans additional known-safe-but-edge locations.
    /// Default OFF. Critical safety property: while on, NOTHING is
    /// pre-selected — every item (routine and deep) must be ticked by hand —
    /// so a deeper scan can never expand what gets deleted without explicit
    /// per-item review. The critical-path denylist and Trash routing are
    /// unchanged and still apply in this mode.
    var strongMode = false

    private let coordinator = ScanCoordinator()
    private let protectionEvaluator = ProtectionEvaluator()
    private let classifier = CacheItemClassifier()
    private var scanTask: Task<Void, Never>?

    var totalReclaimableBytes: Int64 {
        categories.reduce(0) { $0 + $1.totalSizeBytes }
    }

    var selectedItems: [ScannableItem] {
        categories.flatMap(\.items).filter { selectedItemIDs.contains($0.id) }
    }

    var totalSelectedBytes: Int64 {
        selectedItems.reduce(0) { $0 + ($1.sizeBytes ?? 0) }
    }

    var safeReclaimableBytes: Int64 {
        displayGroups
            .filter(\.group.defaultSelected)
            .flatMap(\.items)
            .filter { !$0.item.isProtected }
            .reduce(0) { $0 + ($1.item.sizeBytes ?? 0) }
    }

    var scanIssues: [ScanIssue] { categories.flatMap(\.issues) }

    var trashCategory: ScanCategory? {
        categories.first { $0.id == Self.trashCategoryID }
    }

    /// Every non-Trash item, reclassified into real-world groups and
    /// pooled across scanners — this is what the Clean screen renders.
    var displayGroups: [CleanDisplayGroup] {
        var buckets: [CacheGroup: [ClassifiedItem]] = [:]
        for category in categories where category.id != Self.trashCategoryID {
            for item in category.items {
                let (displayName, group) = classifier.classify(item: item, scannerCategoryID: category.id)
                buckets[group, default: []].append(ClassifiedItem(item: item, displayName: displayName))
            }
        }
        return CacheGroup.allCases
            .filter { $0 != .trash }
            .compactMap { group in
                guard let items = buckets[group], !items.isEmpty else { return nil }
                let sorted = items.sorted { ($0.item.sizeBytes ?? 0) > ($1.item.sizeBytes ?? 0) }
                return CleanDisplayGroup(group: group, items: sorted)
            }
    }

    var filteredDisplayGroups: [CleanDisplayGroup] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return displayGroups.compactMap { group in
            let items = group.items.filter { classified in
                let matchesFilter: Bool
                switch listFilter {
                case .all: matchesFilter = true
                case .selected: matchesFilter = isSelected(classified.item)
                case .review: matchesFilter = !group.group.defaultSelected
                case .protected: matchesFilter = classified.item.isProtected
                }
                guard matchesFilter else { return false }
                guard !needle.isEmpty else { return true }
                return classified.displayName.lowercased().contains(needle)
                    || classified.item.path.lowercased().contains(needle)
            }
            return items.isEmpty ? nil : CleanDisplayGroup(group: group.group, items: items)
        }
    }

    /// Bumped on every start/cancel; late category callbacks from a
    /// superseded scan carry a stale generation and are dropped, so a quick
    /// cancel-then-rescan can't leak old (e.g. deep-mode) categories — or
    /// their default selections — into the new scan's results.
    private var scanGeneration = 0

    func startScan() {
        guard !isCleaning else { return }
        scanTask?.cancel()
        scanGeneration += 1
        let generation = scanGeneration
        categories = []
        selectedItemIDs = []
        lastCleanupSummary = nil
        isScanning = true

        let deep = strongMode
        scanTask = Task {
            _ = await coordinator.scan(deep: deep) { [weak self] category in
                // `onCategoryComplete` runs on `ScanCoordinator`'s own
                // isolation, not MainActor — hop back explicitly before
                // touching view-model state.
                Task { @MainActor in
                    guard let self, self.scanGeneration == generation else { return }
                    self.upsert(category)
                }
            }
            guard !Task.isCancelled, scanGeneration == generation else { return }
            isScanning = false
            hasScannedOnce = true
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanGeneration += 1
        isScanning = false
    }

    func isSelected(_ item: ScannableItem) -> Bool {
        selectedItemIDs.contains(item.id)
    }

    func setSelected(_ item: ScannableItem, _ selected: Bool) {
        if selected {
            selectedItemIDs.insert(item.id)
        } else {
            selectedItemIDs.remove(item.id)
        }
    }

    func setSelected(_ items: [ScannableItem], _ selected: Bool) {
        for item in items {
            setSelected(item, selected)
        }
    }

    /// Runs the confirmed cleanup for every currently-selected item.
    /// Defaults to Trash routing; `permanently` requires the caller to have
    /// already obtained the UI-level "this cannot be undone" acknowledgment
    /// — `DeletionEngine` itself still requires `confirmed: true` as a
    /// second, engine-level gate.
    func performCleanup(permanently: Bool) async {
        guard !selectedItems.isEmpty, !isScanning, !isCleaning else { return }
        isCleaning = true

        let settings = AppSettings.shared
        let engine = settings.makeDeletionEngine()
        let mode = settings.fileDeletionMode(permanent: permanently)
        let isDryRun = settings.dryRunEnabled
        var freed: Int64 = 0
        var deleted = 0
        var skipped = 0
        var failed = 0
        var trashed: [TrashedItem] = []

        for item in selectedItems {
            // Pass the scanner's measured size: without it the engine
            // re-walks each directory synchronously ON the main actor just to
            // annotate its log — multi-second beachballs on big caches.
            let outcome = engine.delete(path: item.path, mode: mode, associatedBundleIdentifier: item.ownerAppBundleID, precomputedSizeBytes: item.sizeBytes)
            switch outcome {
            case .movedToTrash(_, let resultingURL, let size):
                freed += size ?? 0
                deleted += 1
                if let resultingURL {
                    trashed.append(TrashedItem(originalPath: item.path, trashPath: resultingURL.path))
                }
            case .permanentlyDeleted(_, let size):
                freed += size ?? 0
                deleted += 1
            case .wouldDelete(_, let size):
                // Dry-run preview: count as "would free / would remove".
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

        let summary = CleanupSummary(freedBytes: freed, deletedCount: deleted, skippedCount: skipped, failedCount: failed, dryRun: isDryRun)
        if !isDryRun {
            CleanupHistoryStore.shared.record(module: "清理", freedBytes: freed, itemCount: deleted, trashedItems: trashed)
        }
        selectedItemIDs.removeAll()
        // Order matters: `isCleaning` must drop BEFORE startScan() (whose
        // guard would otherwise no-op — the old bug that left every list
        // showing already-deleted items), and the summary must be assigned
        // AFTER startScan() (which resets it to nil) so the completion alert
        // still appears over the fresh scan.
        isCleaning = false
        startScan()
        lastCleanupSummary = summary
    }

    /// Empties Trash by permanently deleting its immediate contents —
    /// never by moving `~/.Trash` itself anywhere. Honors the global
    /// dry-run preview mode.
    func emptyTrash() async {
        guard let trashItem = trashCategory?.items.first, !isScanning, !isCleaning else { return }
        isCleaning = true

        let settings = AppSettings.shared
        let engine = settings.makeDeletionEngine()
        let isDryRun = settings.dryRunEnabled
        let mode: DeletionMode = isDryRun ? .dryRun : .permanent(confirmed: true)
        let childNames = (try? FileManager.default.contentsOfDirectory(atPath: trashItem.path)) ?? []
        var freed: Int64 = 0
        var deleted = 0
        var failed = 0

        for name in childNames {
            let childPath = (trashItem.path as NSString).appendingPathComponent(name)
            let outcome = engine.delete(path: childPath, mode: mode)
            switch outcome {
            case .permanentlyDeleted(_, let size), .wouldDelete(_, let size):
                freed += size ?? 0
                deleted += 1
            case .failed:
                failed += 1
            default:
                break
            }
        }

        // Same ordering as performCleanup: un-block, rescan, then attach the
        // summary after startScan()'s reset so the alert survives.
        // (Deliberately NOT recorded in CleanupHistory: emptying the Trash is
        // permanent by definition — nothing restorable to track.)
        let summary = CleanupSummary(freedBytes: freed, deletedCount: deleted, skippedCount: 0, failedCount: failed, dryRun: isDryRun)
        isCleaning = false
        startScan()
        lastCleanupSummary = summary
    }

    private func upsert(_ category: ScanCategory) {
        let settings = AppSettings.shared
        var annotated = category
        // Drop user-excluded paths from the display entirely, so the list,
        // totals, and selection all reflect what will actually be cleaned.
        // `DeletionEngine` still refuses excluded paths as a backstop.
        annotated.items = annotated.items
            .filter { !settings.isExcluded(resolvedPath: $0.path) }
            .map { item in
                var item = item
                switch protectionEvaluator.evaluate(bundleIdentifier: item.ownerAppBundleID, path: item.path) {
                case .notProtected:
                    item.isProtected = false
                case .staticallyProtected, .runningApp:
                    item.isProtected = true
                }
                return item
            }

        if let index = categories.firstIndex(where: { $0.id == annotated.id }) {
            categories[index] = annotated
        } else {
            categories.append(annotated)
        }

        // Strong mode pre-selects NOTHING — every item must be reviewed and
        // ticked by hand, so a deeper scan can never silently widen the delete
        // set. Normal mode keeps the conservative per-group defaults.
        if !strongMode, annotated.id != Self.trashCategoryID {
            for item in annotated.items where !item.isProtected {
                let (_, group) = classifier.classify(item: item, scannerCategoryID: annotated.id)
                if group.defaultSelected {
                    selectedItemIDs.insert(item.id)
                }
            }
        }
    }

#if DEBUG
    func seedSnapshot(categories: [ScanCategory]) {
        self.categories = []
        selectedItemIDs = []
        hasScannedOnce = true
        categories.forEach(upsert)
    }
#endif
}
