import Foundation

/// Finds large (and optionally stale) individual files under a root directory
/// — the classic "what's eating my disk" second feature. It only *reports*;
/// deletion goes through the audited `DeletionEngine` (Trash) like everything
/// else. Sizes are actual on-disk allocation (sparse-file-safe), so a sparse
/// `Docker.raw` won't be mis-reported as huge.
public struct LargeFileScanner: Sendable {
    public struct Candidate: Identifiable, Sendable, Equatable {
        public let id: String
        public let path: String
        public let sizeBytes: Int64
        public let lastAccessDate: Date?
        /// Not accessed within `oldThresholdDays` — a hint it may be forgotten.
        public let isOld: Bool

        public var displayName: String { (path as NSString).lastPathComponent }

        public init(path: String, sizeBytes: Int64, lastAccessDate: Date?, isOld: Bool) {
            self.id = path
            self.path = path
            self.sizeBytes = sizeBytes
            self.lastAccessDate = lastAccessDate
            self.isOld = isOld
        }
    }

    public struct Progress: Sendable {
        public let currentPath: String
        public let foundCount: Int
    }

    public let minBytes: Int64
    public let oldThresholdDays: Int

    public init(minBytes: Int64 = 100 * 1024 * 1024, oldThresholdDays: Int = 180) {
        self.minBytes = minBytes
        self.oldThresholdDays = oldThresholdDays
    }

    public static func defaultRoot(homeDirectory: String = NSHomeDirectory()) -> String {
        homeDirectory
    }

    public func scan(root: String, onProgress: (@Sendable (Progress) -> Void)? = nil) async -> [Candidate] {
        let fm = FileManager.default
        let now = Date()
        let oldCutoff = now.addingTimeInterval(-Double(oldThresholdDays) * 86_400)
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey, .isSymbolicLinkKey,
            .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .contentAccessDateKey,
        ]

        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: root),
            includingPropertiesForKeys: Array(keys),
            // Skip hidden noise (.git etc.) and treat bundles (.app/.photoslibrary)
            // as opaque so we don't list a thousand files inside them.
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var found: [Candidate] = []
        var checked = 0
        while let object = enumerator.nextObject() {
            guard let url = object as? URL else { continue }
            checked += 1
            if checked % 512 == 0 {
                if Task.isCancelled { break }
                await Task.yield()
                onProgress?(Progress(currentPath: url.deletingLastPathComponent().path, foundCount: found.count))
            }
            guard let values = try? url.resourceValues(forKeys: keys) else { continue }
            if values.isSymbolicLink == true { continue }
            guard values.isRegularFile == true else { continue }
            let size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            guard size >= minBytes else { continue }
            let access = values.contentAccessDate
            let isOld = (access ?? now) < oldCutoff
            found.append(Candidate(path: url.path, sizeBytes: size, lastAccessDate: access, isOld: isOld))
        }
        return found.sorted { $0.sizeBytes > $1.sizeBytes }
    }
}
