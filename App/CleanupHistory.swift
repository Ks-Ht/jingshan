import Foundation

/// One item that was moved to Trash during a cleanup, remembered so it can be
/// restored to exactly where it came from (B2 one-click restore).
struct TrashedItem: Codable, Equatable {
    let originalPath: String
    let trashPath: String
}

/// A single cleanup event, persisted locally as an audit trail of "what did I
/// actually delete" (A1) and the backing data for one-click restore (B2).
struct CleanupRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    /// Which module ran it, e.g. "清理" / "构建产物" / "卸载应用".
    let module: String
    let freedBytes: Int64
    let itemCount: Int
    /// The subset of deleted items that went to Trash (permanent deletions
    /// aren't restorable and are omitted here).
    var trashedItems: [TrashedItem]
    var restored: Bool = false
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
    /// pass `itemCount: 0` / no items in those cases).
    func record(module: String, freedBytes: Int64, itemCount: Int, trashedItems: [TrashedItem]) {
        guard itemCount > 0 else { return }
        let entry = CleanupRecord(
            id: UUID(),
            date: Date(),
            module: module,
            freedBytes: freedBytes,
            itemCount: itemCount,
            trashedItems: trashedItems
        )
        records.insert(entry, at: 0)
        if records.count > Self.maxRecords {
            records = Array(records.prefix(Self.maxRecords))
        }
        save()
    }

    /// Restores a cleanup's trashed items back to their original locations.
    /// Purely additive/non-destructive: an item is moved back only if it's
    /// still in the Trash AND its original path is currently free (never
    /// overwrites anything). Returns how many were restored vs. failed.
    @discardableResult
    func restore(_ record: CleanupRecord) -> (restored: Int, failed: Int) {
        let fm = FileManager.default
        var restored = 0
        var failed = 0
        for item in record.trashedItems {
            let source = URL(fileURLWithPath: item.trashPath)
            let destination = URL(fileURLWithPath: item.originalPath)
            guard fm.fileExists(atPath: source.path) else { continue } // already gone from Trash
            guard !fm.fileExists(atPath: destination.path) else { failed += 1; continue } // won't overwrite
            do {
                try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.moveItem(at: source, to: destination)
                restored += 1
            } catch {
                failed += 1
            }
        }
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index].restored = true
            save()
        }
        return (restored, failed)
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
