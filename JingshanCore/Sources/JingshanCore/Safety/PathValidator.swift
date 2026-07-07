import Foundation

/// Reasons a path is refused as a deletion target. Mirrors Mole's
/// `validate_path_for_deletion` policy, ported to typed Swift errors.
public enum PathValidationError: Error, Equatable, CustomStringConvertible {
    case notAbsolute(String)
    case containsTraversal(String)
    case containsControlCharacters(String)
    case matchesCriticalDenylist(resolvedPath: String, rule: String)
    case isUserHomeRoot(String)
    case pathDoesNotExist(String)

    public var description: String {
        switch self {
        case .notAbsolute(let path):
            return "path is not absolute: \(path)"
        case .containsTraversal(let path):
            return "path contains a \"..\" traversal component: \(path)"
        case .containsControlCharacters(let path):
            return "path contains control characters: \(path)"
        case .matchesCriticalDenylist(let resolvedPath, let rule):
            return "resolved path matches critical denylist rule \"\(rule)\": \(resolvedPath)"
        case .isUserHomeRoot(let path):
            return "path is the user's home directory root: \(path)"
        case .pathDoesNotExist(let path):
            return "path does not exist: \(path)"
        }
    }
}

/// A path that has passed all safety checks: it is absolute, free of
/// traversal/control characters, resolved past any symlinks, clear of the
/// critical-path denylist and the user's home root, and currently exists.
public struct ValidatedPath: Equatable, Sendable {
    public let originalPath: String
    public let resolvedPath: String
    public let isDirectory: Bool
    public let isSymbolicLink: Bool
}

public protocol PathValidating {
    func validate(_ path: String) -> Result<ValidatedPath, PathValidationError>
}

/// Single choke point for "is it safe to delete this path". Every deletion
/// in JingshanCore must pass through here first; nothing else should decide
/// on its own that a path is safe.
public struct PathValidator: PathValidating {
    private let denylist: CriticalPathDenylist
    private let fileManager: FileManager
    private let homeDirectory: String

    public init(
        denylist: CriticalPathDenylist = .default,
        fileManager: FileManager = .default,
        homeDirectory: String = NSHomeDirectory()
    ) {
        self.denylist = denylist
        self.fileManager = fileManager
        self.homeDirectory = PathValidator.normalize(homeDirectory)
    }

    public func validate(_ path: String) -> Result<ValidatedPath, PathValidationError> {
        guard path.hasPrefix("/") else {
            return .failure(.notAbsolute(path))
        }

        if PathValidator.containsTraversalComponent(path) {
            return .failure(.containsTraversal(path))
        }

        if PathValidator.containsControlCharacters(path) {
            return .failure(.containsControlCharacters(path))
        }

        // Resolve past every symlink hop so a symlink hidden inside an
        // otherwise-safe folder cannot smuggle a delete out to a denylisted
        // system path. Every check from here on runs against the resolved
        // path, never the literal input.
        let resolvedPath = PathValidator.normalize((path as NSString).resolvingSymlinksInPath)

        if let rule = denylist.firstMatch(forResolvedPath: resolvedPath) {
            return .failure(.matchesCriticalDenylist(resolvedPath: resolvedPath, rule: rule.pathPrefix))
        }

        if resolvedPath == homeDirectory {
            return .failure(.isUserHomeRoot(resolvedPath))
        }

        var isDirValue: ObjCBool = false
        let existsFollowingSymlink = fileManager.fileExists(atPath: resolvedPath, isDirectory: &isDirValue)
        let symlinkDestination = try? fileManager.destinationOfSymbolicLink(atPath: path)
        let isSymlink = symlinkDestination != nil

        guard existsFollowingSymlink || isSymlink else {
            return .failure(.pathDoesNotExist(path))
        }

        return .success(
            ValidatedPath(
                originalPath: path,
                resolvedPath: resolvedPath,
                isDirectory: existsFollowingSymlink && isDirValue.boolValue,
                isSymbolicLink: isSymlink
            )
        )
    }

    static func containsTraversalComponent(_ path: String) -> Bool {
        path.split(separator: "/", omittingEmptySubsequences: true).contains { $0 == ".." }
    }

    static func containsControlCharacters(_ path: String) -> Bool {
        path.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }

    public static func normalize(_ path: String) -> String {
        var normalized = path
        while normalized.contains("//") {
            normalized = normalized.replacingOccurrences(of: "//", with: "/")
        }
        if normalized.count > 1 && normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        return normalized.isEmpty ? "/" : normalized
    }
}
