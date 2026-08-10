import Foundation

/// One item that was moved to Trash during a cleanup, remembered so it can be
/// restored to exactly where it came from (one-click restore).
///
/// `fileSize`/`inode` fingerprint the file AS TRASHED, so restore can refuse
/// to move back a *different* file that later re-occupied the same Trash path
/// (empty Trash → delete another same-named file → its resulting Trash URL
/// can be identical). Optional so records persisted before these fields
/// existed still decode.
public struct TrashedItem: Codable, Equatable, Sendable {
    public let originalPath: String
    public let trashPath: String
    public var fileSize: Int64?
    public var inode: UInt64?

    public init(originalPath: String, trashPath: String, fileSize: Int64? = nil, inode: UInt64? = nil) {
        self.originalPath = originalPath
        self.trashPath = trashPath
        self.fileSize = fileSize
        self.inode = inode
    }

    /// Captures the identity fingerprint of the just-trashed file. Call right
    /// after the move to Trash, while the path is guaranteed fresh.
    public func fingerprinted(fileManager: FileManager = .default) -> TrashedItem {
        var item = self
        if let attrs = try? fileManager.attributesOfItem(atPath: trashPath) {
            item.fileSize = (attrs[.size] as? NSNumber)?.int64Value
            item.inode = (attrs[.systemFileNumber] as? NSNumber)?.uint64Value
        }
        return item
    }
}

/// Moves trashed items back to their original locations — the ONLY code in
/// 净山 that moves user files back out of the Trash. Deliberately additive
/// and conservative:
///
/// - sources must live inside a real Trash directory (a tampered/corrupted
///   history entry can never turn restore into an arbitrary move primitive);
/// - a stored fingerprint must still match (never restores a *different*
///   same-named file that re-occupied the Trash path);
/// - an existing file at the original path is NEVER overwritten.
///
/// Retryable failures (destination occupied, move error) are returned in
/// `remaining` so the caller can offer restore again; impossible items
/// (gone from Trash, fingerprint mismatch, invalid source) are dropped.
public enum CleanupRestorer {
    public struct Outcome: Sendable, Equatable {
        public let restoredCount: Int
        public let failedCount: Int
        /// Items still worth retrying later (e.g. original path currently occupied).
        public let remaining: [TrashedItem]
    }

    public static func defaultTrashRoots(homeDirectory: String = NSHomeDirectory()) -> [String] {
        [homeDirectory + "/.Trash"]
    }

    public static func restore(
        _ items: [TrashedItem],
        trashRoots: [String]? = nil,
        fileManager: FileManager = .default
    ) -> Outcome {
        let roots: [String]
        if let trashRoots {
            roots = trashRoots.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().standardizedFileURL.path }
        } else {
            var inferredRoots = defaultTrashRoots()
            for item in items {
                let url = URL(fileURLWithPath: item.trashPath)
                guard let trashURL = try? fileManager.url(
                    for: .trashDirectory,
                    in: .userDomainMask,
                    appropriateFor: url,
                    create: false
                ),
                      let root = trustedTrashRoot(trashPath: item.trashPath, candidateRoot: trashURL.path)
                else { continue }
                inferredRoots.append(root)
            }
            roots = Array(Set(inferredRoots)).map {
                URL(fileURLWithPath: $0).resolvingSymlinksInPath().standardizedFileURL.path
            }
        }
        var restored = 0
        var failed = 0
        var remaining: [TrashedItem] = []

        for item in items {
            let sourcePath = (item.trashPath as NSString).standardizingPath
            let destinationPath = (item.originalPath as NSString).standardizingPath

            // Anchor: only ever move OUT of a Trash directory. Resolve the
            // entire ancestor chain before comparing so `Trash/pivot/file`,
            // where `pivot` is a symlink to somewhere outside the Trash,
            // cannot pass a lexical-prefix check. Deliberately do NOT
            // resolve the final component: a symlink that was itself put in
            // the Trash is a legitimate item and moving it restores only the
            // link entry, not its target.
            guard let anchoredSourcePath = anchoredTrashSourcePath(sourcePath, roots: roots) else {
                failed += 1 // unrestorable by construction — drop
                continue
            }
            guard pathEntryExists(atPath: anchoredSourcePath, fileManager: fileManager) else {
                failed += 1 // gone from Trash (emptied) — drop, can never succeed
                continue
            }
            // Identity check: is this still the same file we trashed?
            if item.fileSize != nil || item.inode != nil {
                let attrs = try? fileManager.attributesOfItem(atPath: anchoredSourcePath)
                let size = (attrs?[.size] as? NSNumber)?.int64Value
                let inode = (attrs?[.systemFileNumber] as? NSNumber)?.uint64Value
                if (item.fileSize != nil && size != item.fileSize) || (item.inode != nil && inode != item.inode) {
                    failed += 1 // a different file re-occupied the path — drop
                    continue
                }
            }
            // Never overwrite whatever now lives at the original path.
            guard !pathEntryExists(atPath: destinationPath, fileManager: fileManager) else {
                failed += 1
                remaining.append(item) // retryable once the user clears the spot
                continue
            }
            do {
                let destinationURL = URL(fileURLWithPath: destinationPath)
                try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileManager.moveItem(at: URL(fileURLWithPath: anchoredSourcePath), to: destinationURL)
                restored += 1
            } catch {
                failed += 1
                remaining.append(item) // transient error — retryable
            }
        }
        return Outcome(restoredCount: restored, failedCount: failed, remaining: remaining)
    }

    static func trustedTrashRoot(trashPath: String, candidateRoot: String) -> String? {
        let source = (trashPath as NSString).standardizingPath
        let normalizedRoot = (candidateRoot as NSString).standardizingPath
        return source.hasPrefix(normalizedRoot + "/") ? normalizedRoot : nil
    }

    static func anchoredTrashSourcePath(_ sourcePath: String, roots: [String]) -> String? {
        let sourceURL = URL(fileURLWithPath: sourcePath).standardizedFileURL
        let resolvedParent = sourceURL
            .deletingLastPathComponent()
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let anchoredSource = resolvedParent.appendingPathComponent(sourceURL.lastPathComponent).path

        guard roots.contains(where: { root in
            let resolvedRoot = URL(fileURLWithPath: root).resolvingSymlinksInPath().standardizedFileURL.path
            return resolvedParent.path == resolvedRoot || resolvedParent.path.hasPrefix(resolvedRoot + "/")
        }) else { return nil }
        return anchoredSource
    }

    /// `fileExists(atPath:)` follows the final symlink and therefore reports
    /// `false` for a dangling link. Restore operates on directory entries, so
    /// detect symlinks without following the final component as well.
    static func pathEntryExists(atPath path: String, fileManager: FileManager) -> Bool {
        fileManager.fileExists(atPath: path)
            || (try? fileManager.destinationOfSymbolicLink(atPath: path)) != nil
    }
}
