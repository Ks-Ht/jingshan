import Foundation

/// Recursively walks a set of root directories (typically `~/Projects`,
/// `~/GitHub`, `~/dev`, or user-configured paths) looking for build
/// artifact directories matching `PurgeArtifactRule.defaultRules`.
///
/// Safety properties, all deliberate:
/// - Never follows symbolic links while walking (avoids symlink cycles and
///   escaping the intended tree onto an unrelated part of the filesystem).
/// - Never descends into `.git` (irrelevant to build artifacts, and walking
///   a large repo's object store would be pure waste).
/// - Stops descending the moment a directory matches a rule — an artifact
///   directory is treated as one atomic reclaimable unit; deleting it
///   deletes everything nested inside anyway, so looking further inside is
///   both wasted work and pointless.
/// - Bounded recursion depth and cooperative cancellation, since project
///   trees (especially an unfiltered `node_modules`) can be huge.
public struct PurgeScanner: Sendable {
    private let rules: [PurgeArtifactRule]
    private let recentThresholdDays: Int
    private let maxDepth: Int

    public init(
        rules: [PurgeArtifactRule] = PurgeArtifactRule.defaultRules,
        recentThresholdDays: Int = 7,
        maxDepth: Int = 10
    ) {
        self.rules = rules
        self.recentThresholdDays = recentThresholdDays
        self.maxDepth = maxDepth
    }

    public static func defaultRoots(homeDirectory: String = NSHomeDirectory(), fileManager: FileManager = .default) -> [String] {
        ["Projects", "Developer", "GitHub", "dev"]
            .map { homeDirectory + "/" + $0 }
            .filter { fileManager.fileExists(atPath: $0) }
    }

    /// Progress snapshot for live scan feedback: which directory is being
    /// walked right now, and how many artifacts have been found so far.
    public struct Progress: Sendable {
        public let currentPath: String
        public let foundCount: Int
        public init(currentPath: String, foundCount: Int) {
            self.currentPath = currentPath
            self.foundCount = foundCount
        }
    }

    /// Sequential accumulator so a running found-count can be reported mid-
    /// walk. Only ever touched by the single scan task (never sent across
    /// tasks), so the unchecked conformance is safe.
    private final class Accumulator: @unchecked Sendable {
        var results: [PurgeCandidate] = []
    }

    public func scan(roots: [String], onProgress: (@Sendable (Progress) -> Void)? = nil) async -> [PurgeCandidate] {
        let acc = Accumulator()
        for root in roots {
            if Task.isCancelled { break }
            await walk(directory: root, depth: 0, acc: acc, onProgress: onProgress)
        }
        return acc.results
    }

    private func walk(directory: String, depth: Int, acc: Accumulator, onProgress: (@Sendable (Progress) -> Void)?) async {
        guard depth <= maxDepth, !Task.isCancelled else { return }
        // Report on entering the top few levels (few, high-signal — the
        // project being scanned) rather than every directory, to keep UI
        // update frequency sane on deep trees.
        if depth <= 2 { onProgress?(Progress(currentPath: directory, foundCount: acc.results.count)) }

        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(atPath: directory) else { return }
        let siblingNames = Set(entries)

        for (index, entry) in entries.enumerated() {
            if index % 64 == 0 {
                if Task.isCancelled { return }
                await Task.yield()
            }
            if entry == ".git" { continue }

            let fullPath = (directory as NSString).appendingPathComponent(entry)

            // Never follow symlinks: a directory symlink here could point
            // anywhere (including back up the tree, causing infinite
            // recursion) or outside the intended scan root entirely.
            if (try? fileManager.destinationOfSymbolicLink(atPath: fullPath)) != nil {
                continue
            }

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }

            if let rule = rules.first(where: { $0.directoryName == entry }), rule.isSatisfied(bySiblingNames: siblingNames) {
                let size = await FileSizeCalculator.sizeAsync(ofPath: fullPath)
                let projectName = (directory as NSString).lastPathComponent
                let isRecent = Self.isRecentlyModified(directory, thresholdDays: recentThresholdDays, fileManager: fileManager)
                acc.results.append(
                    PurgeCandidate(
                        id: PathValidator.normalize(fullPath),
                        path: fullPath,
                        projectName: projectName,
                        artifactLabel: rule.displayLabel,
                        sizeBytes: size,
                        isRecent: isRecent,
                        riskNote: rule.riskNote
                    )
                )
                onProgress?(Progress(currentPath: fullPath, foundCount: acc.results.count))
                continue
            }

            await walk(directory: fullPath, depth: depth + 1, acc: acc, onProgress: onProgress)
        }
    }

    private static func isRecentlyModified(_ path: String, thresholdDays: Int, fileManager: FileManager) -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: path),
            let modificationDate = attributes[.modificationDate] as? Date
        else {
            return false
        }
        let threshold = Date().addingTimeInterval(-Double(thresholdDays) * 86400)
        return modificationDate > threshold
    }
}
