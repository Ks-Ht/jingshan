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
        ["Projects", "GitHub", "dev"]
            .map { homeDirectory + "/" + $0 }
            .filter { fileManager.fileExists(atPath: $0) }
    }

    public func scan(roots: [String]) async -> [PurgeCandidate] {
        var results: [PurgeCandidate] = []
        for root in roots {
            if Task.isCancelled { break }
            results.append(contentsOf: await walk(directory: root, depth: 0))
        }
        return results
    }

    private func walk(directory: String, depth: Int) async -> [PurgeCandidate] {
        guard depth <= maxDepth, !Task.isCancelled else { return [] }
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(atPath: directory) else { return [] }
        let siblingNames = Set(entries)

        var results: [PurgeCandidate] = []
        for (index, entry) in entries.enumerated() {
            if index % 64 == 0 {
                if Task.isCancelled { break }
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
                results.append(
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
                continue
            }

            results.append(contentsOf: await walk(directory: fullPath, depth: depth + 1))
        }
        return results
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
