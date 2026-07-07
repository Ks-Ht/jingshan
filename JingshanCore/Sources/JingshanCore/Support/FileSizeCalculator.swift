import Foundation

/// Best-effort, synchronous size calculation used by `DeletionEngine` to
/// annotate log entries when the caller has not already measured a size.
///
/// This is intentionally minimal for M1. The Scanning module (M2) needs an
/// async, cancellable, progress-reporting variant for walking large
/// directory trees during a scan; that will be added alongside the
/// scanners rather than growing this type into something it isn't yet.
public enum FileSizeCalculator {
    public static func size(ofPath path: String, fileManager: FileManager = .default) -> Int64? {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return nil
        }

        if !isDirectory.boolValue {
            let attributes = try? fileManager.attributesOfItem(atPath: path)
            return (attributes?[.size] as? NSNumber)?.int64Value
        }

        guard let enumerator = fileManager.enumerator(atPath: path) else {
            return nil
        }

        var total: Int64 = 0
        for case let name as String in enumerator {
            let fullPath = (path as NSString).appendingPathComponent(name)
            guard let attributes = try? fileManager.attributesOfItem(atPath: fullPath) else { continue }
            if (attributes[.type] as? FileAttributeType) != .typeDirectory {
                total += (attributes[.size] as? NSNumber)?.int64Value ?? 0
            }
        }
        return total
    }

    /// Async, cooperatively-cancellable variant for the Scanning module,
    /// which walks much larger trees (e.g. `~/Library/Caches`) than
    /// `DeletionEngine`'s per-item logging ever does. Must be called from a
    /// non-main-actor context; it periodically checks `Task.isCancelled`
    /// and yields so a scan can be cancelled mid-walk instead of blocking
    /// until a huge directory finishes enumerating.
    public static func sizeAsync(ofPath path: String) async -> Int64? {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return nil
        }

        if !isDirectory.boolValue {
            let attributes = try? fileManager.attributesOfItem(atPath: path)
            return (attributes?[.size] as? NSNumber)?.int64Value
        }

        guard let enumerator = fileManager.enumerator(atPath: path) else {
            return nil
        }

        // Materialize the names up front: NSEnumerator's fast-enumeration
        // bridging (`for case ... in enumerator`) is unavailable from async
        // contexts, and this also gives a stable snapshot to iterate with
        // cooperative cancellation checks below.
        let names = enumerator.allObjects as? [String] ?? []

        var total: Int64 = 0
        var checked = 0
        for name in names {
            checked += 1
            if checked % 256 == 0 {
                if Task.isCancelled { return nil }
                await Task.yield()
            }
            let fullPath = (path as NSString).appendingPathComponent(name)
            guard let attributes = try? fileManager.attributesOfItem(atPath: fullPath) else { continue }
            if (attributes[.type] as? FileAttributeType) != .typeDirectory {
                total += (attributes[.size] as? NSNumber)?.int64Value ?? 0
            }
        }
        return total
    }
}
