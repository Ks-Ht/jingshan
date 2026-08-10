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
            return allocatedSize(ofPath: path)
        }

        guard let enumerator = fileManager.enumerator(atPath: path) else {
            return nil
        }

        // Sum actual on-disk allocation per file (not logical `.fileSize`), so
        // the total is "space you'd actually reclaim" — block-rounded for many
        // small files, and correct (not inflated) for sparse files.
        var total: Int64 = 0
        for case let name as String in enumerator {
            let fullPath = (path as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue else { continue }
            total += allocatedSize(ofPath: fullPath) ?? 0
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
            return allocatedSize(ofPath: path)
        }

        // Stream the tree with the URL enumerator (one metadata fetch per
        // entry, cancellable mid-walk) instead of the old `allObjects`
        // approach, which materialized every path string up front — an
        // uncancellable full-tree walk before the first size was summed.
        // Symlinks are skipped outright: following one would bill the TARGET's
        // size to this directory while deleting only removes the link.
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: Array(keys)
        ) else {
            return nil
        }

        // Sum actual on-disk allocation per file (not logical `.fileSize`) — the
        // real reclaimable-space figure, and sparse-file-safe.
        var total: Int64 = 0
        var checked = 0
        while let object = enumerator.nextObject() {
            guard let url = object as? URL else { continue }
            checked += 1
            if checked % 256 == 0 {
                if Task.isCancelled { return nil }
                await Task.yield()
            }
            guard let values = try? url.resourceValues(forKeys: keys) else { continue }
            if values.isSymbolicLink == true { continue }
            guard values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }
}
