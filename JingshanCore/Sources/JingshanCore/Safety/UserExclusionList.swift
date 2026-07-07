import Foundation

/// User-editable exclusions, consulted by both the scanners (so an excluded
/// item never even shows up as "will be cleaned") and `DeletionEngine`
/// (so nothing bypasses the exclusion by a different code path). Mirrors
/// Mole's user whitelist.
public struct UserExclusionList: Codable, Equatable, Sendable {
    public var excludedPaths: Set<String>
    public var excludedBundleIdentifiers: Set<String>

    public init(excludedPaths: Set<String> = [], excludedBundleIdentifiers: Set<String> = []) {
        self.excludedPaths = Set(excludedPaths.map(PathValidator.normalize))
        self.excludedBundleIdentifiers = excludedBundleIdentifiers
    }

    public static func load(from url: URL) throws -> UserExclusionList {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return UserExclusionList()
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(UserExclusionList.self, from: data)
    }

    public func save(to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let data = try JSONEncoder().encode(self)
        try data.write(to: url, options: .atomic)
    }

    /// True if `resolvedPath` was explicitly excluded, or is nested inside an
    /// excluded directory.
    public func contains(resolvedPath: String) -> Bool {
        let normalized = PathValidator.normalize(resolvedPath)
        return excludedPaths.contains { excluded in
            normalized == excluded || normalized.hasPrefix(excluded + "/")
        }
    }

    public func containsBundleIdentifier(_ bundleIdentifier: String) -> Bool {
        excludedBundleIdentifiers.contains(bundleIdentifier)
    }
}
