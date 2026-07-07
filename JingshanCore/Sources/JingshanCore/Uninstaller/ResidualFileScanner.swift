import Foundation

/// Finds which of `ResidualLocationRule.defaultRules` actually exist on
/// disk for a given app. Every rule is a plain existence check against a
/// computed path — nothing there ever globs, prefix-matches, or otherwise
/// guesses, so a rule can only ever surface the exact location it names.
/// The one deliberate exception is login-item agents (see
/// `scanLaunchAgents` below), which structurally cannot be a single fixed
/// path — that exception is scoped as narrowly as possible.
public struct ResidualFileScanner: Sendable {
    private let rules: [ResidualLocationRule]

    public init(rules: [ResidualLocationRule] = ResidualLocationRule.defaultRules) {
        self.rules = rules
    }

    public func scanResiduals(for app: InstalledApplication, homeDirectory: String = NSHomeDirectory()) async -> [ResidualCandidate] {
        let fileManager = FileManager.default
        var seenPaths = Set<String>()
        var results: [ResidualCandidate] = []
        for rule in rules {
            if Task.isCancelled { break }
            let path = rule.expectedPath(for: app, homeDirectory: homeDirectory)
            // Two rules (bundle-id-keyed and name-keyed Application Support)
            // can coincidentally compute the same path; only surface it once.
            guard fileManager.fileExists(atPath: path), seenPaths.insert(path).inserted else { continue }
            let size = await FileSizeCalculator.sizeAsync(ofPath: path)
            results.append(
                ResidualCandidate(path: path, displayLabel: rule.displayLabel, tier: rule.tier, riskNote: rule.riskNote, sizeBytes: size)
            )
        }

        for candidate in await scanLaunchAgents(for: app, homeDirectory: homeDirectory, fileManager: fileManager) {
            guard seenPaths.insert(candidate.path).inserted else { continue }
            results.append(candidate)
        }

        return results
    }

    /// Login-item registration files are the one residual location that
    /// isn't a single fixed path: an app can register several helper
    /// agents, each named `<bundle id>.<suffix>.plist` (e.g.
    /// `com.docker.docker.helper.plist`), not just `<bundle id>.plist`.
    /// This lists exactly one directory (`~/Library/LaunchAgents`, never
    /// `/Library/LaunchAgents` — the system-wide one needs root and is out
    /// of scope) and keeps only filenames that are exactly
    /// `<bundle id>.plist` or start with `<bundle id>.` — the trailing dot
    /// means a different app whose id merely shares this one as a raw text
    /// prefix with no separator (e.g. `com.docker.dockerclient` vs
    /// `com.docker.docker`) can never match, since after the shared prefix
    /// comes `client`, not `.`. The residual, accepted risk: a *dot-suffixed*
    /// sibling bundle id (`com.acme.helper` as some other, independent app's
    /// own full identifier, not literally a helper of `com.acme`) would
    /// still match if `com.acme` were uninstalled — reverse-DNS bundle ids
    /// are meant to be hierarchically owned by whoever controls that
    /// namespace, so treating `com.acme.*` as "belongs with com.acme" is the
    /// same assumption macOS's own helper-process convention relies on, and
    /// every mainstream uninstaller (AppCleaner, Pearcleaner, etc.) makes
    /// the same trade-off. The blast radius if it's ever wrong is a single
    /// Trash-recoverable, zero-user-data login-item plist — never the
    /// sibling app's binary or its actual data, which live elsewhere and are
    /// never touched by this rule.
    private func scanLaunchAgents(for app: InstalledApplication, homeDirectory: String, fileManager: FileManager) async -> [ResidualCandidate] {
        let directory = homeDirectory + "/Library/LaunchAgents"
        guard let entries = try? fileManager.contentsOfDirectory(atPath: directory) else { return [] }

        let exactMatch = app.bundleIdentifier + ".plist"
        let prefix = app.bundleIdentifier + "."
        var results: [ResidualCandidate] = []
        for entry in entries.sorted() {
            guard entry.hasSuffix(".plist"), entry == exactMatch || entry.hasPrefix(prefix) else { continue }
            let path = directory + "/" + entry
            let size = await FileSizeCalculator.sizeAsync(ofPath: path)
            results.append(
                ResidualCandidate(
                    path: path,
                    displayLabel: "登录启动项",
                    tier: .safe,
                    riskNote: "开机/登录自动启动的注册项，可安全删除；如果对应的后台程序当前正在运行，删除后不会立即停止，但下次登录不会再自动启动。",
                    sizeBytes: size
                )
            )
        }
        return results
    }
}
