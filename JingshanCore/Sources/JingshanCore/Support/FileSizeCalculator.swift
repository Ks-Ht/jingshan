import Foundation

/// Best-effort, synchronous size calculation used by `DeletionEngine` to
/// annotate log entries when the caller has not already measured a size.
///
/// This is intentionally minimal for M1. The Scanning module (M2) needs an
/// async, cancellable, progress-reporting variant for walking large
/// directory trees during a scan; that will be added alongside the
/// scanners rather than growing this type into something it isn't yet.
public enum FileSizeCalculator {
    /// Actual on-disk allocation of a single file (not its logical/apparent
    /// size). For a sparse file the two diverge wildly — Docker's VM disk
    /// image `Docker.raw` reports a logical size of roughly the whole volume
    /// (~228 GB on the dev machine) while it actually occupies far less
    /// (~1.8 GB). The logical size is both wrong and alarming for a "space
    /// you'd reclaim" figure, so anything sparse must be measured this way.
    /// Returns the same number `du` reports (`st_blocks × 512`, surfaced here
    /// via `totalFileAllocatedSize`).
    public static func allocatedSize(ofPath path: String) -> Int64? {
        let url = URL(fileURLWithPath: path)
        guard let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey]) else {
            return nil
        }
        if let allocated = values.totalFileAllocatedSize { return Int64(allocated) }
        if let allocated = values.fileAllocatedSize { return Int64(allocated) }
        if let logical = values.fileSize { return Int64(logical) }
        return nil
    }

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
