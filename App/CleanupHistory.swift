import Foundation
import JingshanCore

/// A single cleanup event, persisted locally as an audit trail of "what did I
/// actually delete" (A1) and the backing data for one-click restore (B2).
/// `TrashedItem` and the restore algorithm live in `JingshanCore` (History/)
/// where they are unit-tested; this record + store is the App-side
/// persistence/observation shell.
struct CleanupRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    /// Which module ran it, e.g. "清理" / "构建产物" / "卸载应用" / "大文件".
    let module: String
    let freedBytes: Int64
    let itemCount: Int
    /// The still-restorable subset of deleted items (moved to Trash and not
    /// yet successfully restored). Permanent deletions are never in here;
    /// successfully restored / permanently-unrestorable entries are removed
    /// by `restore`.
    var trashedItems: [TrashedItem]
    var restored: Bool = false
    /// Optional for backwards-compatible decoding of records written before
    /// v0.9.0. `true` means a restore attempt permanently lost at least one
    /// item (missing from Trash, fingerprint mismatch, or invalid source), so
    /// an empty retry list must not be presented as "已恢复".
    var restoreHadFailures: Bool?
}

/// Local, private cleanup history (never uploaded). Persisted as JSON under
/// Application Support. Records are newest-first and capped so the file can't
/// grow without bound.
@MainActor
@Observable
final class CleanupHistoryStore {
    static let shared = CleanupHistoryStore()

    private(set) var records: [CleanupRecord] = []
    private let url: URL
    private static let maxRecords = 100

    init(url: URL = CleanupHistoryStore.defaultURL) {
        self.url = url
        load()
    }

    static var defaultURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/Jingshan/cleanup-history.json")
    }

    var totalFreedBytes: Int64 { records.reduce(0) { $0 + $1.freedBytes } }
    var totalCleanupCount: Int { records.count }

    /// Appends a cleanup event. No-op for empty cleanups and dry-runs (callers
    /// pass `itemCount: 0` / no items in those cases). Each trashed file is
    /// fingerprinted (size + inode) while fresh, so restore can later verify
    /// it's still the SAME file at that Trash path.
    func record(module: String, freedBytes: Int64, itemCount: Int, trashedItems: [TrashedItem]) {
        guard itemCount > 0 else { return }
        let entry = CleanupRecord(
            id: UUID(),
            date: Date(),
            module: module,
            freedBytes: freedBytes,
            itemCount: itemCount,
            trashedItems: trashedItems.map { $0.fingerprinted() },
            restoreHadFailures: nil
        )
        records.insert(entry, at: 0)
        if records.count > Self.maxRecords {
            records = Array(records.prefix(Self.maxRecords))
        }
        save()
    }

    /// Restores a cleanup's trashed items back to their original locations via
    /// the audited `CleanupRestorer` (Trash-anchored, fingerprint-verified,
    /// never overwrites). Retryable failures stay on the record so the
    /// restore button remains available; the record is only marked restored
    /// once nothing restorable is left.
    @discardableResult
    func restore(_ record: CleanupRecord) -> (restored: Int, failed: Int) {
        let outcome = CleanupRestorer.restore(record.trashedItems)
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index].trashedItems = outcome.remaining
            records[index].restoreHadFailures = outcome.failedCount > 0
            if outcome.remaining.isEmpty && outcome.failedCount == 0 {
                records[index].restored = true
            } else {
                records[index].restored = false
            }
            save()
        }
        return (outcome.restoredCount, outcome.failedCount)
    }

    func clear() {
        records = []
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([CleanupRecord].self, from: data)
        else { return }
        records = decoded
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(records)
            try data.write(to: url, options: .atomic)
        } catch {
            // History is best-effort; a persistence failure must never break a
            // cleanup that already succeeded.
        }
    }
}
