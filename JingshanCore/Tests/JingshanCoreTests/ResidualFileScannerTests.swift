import Foundation
import Testing

@testable import JingshanCore

@Suite("ResidualFileScanner")
struct ResidualFileScannerTests {
    private let fm = FileManager.default

    private func app(bundleIdentifier: String = "com.example.app", displayName: String = "Example") -> InstalledApplication {
        InstalledApplication(path: "/Applications/\(displayName).app", bundleIdentifier: bundleIdentifier, displayName: displayName, versionString: "1.0")
    }

    @Test("finds an existing residual directory and reports its size")
    func findsExistingResidual() async throws {
        let home = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(home) }
        let cachesDir = home.appendingPathComponent("Library/Caches/com.example.app", isDirectory: true)
        try fm.createDirectory(at: cachesDir, withIntermediateDirectories: true)
        try TestFixtures.writeFile(at: cachesDir.appendingPathComponent("cache.db"), contents: "some cached bytes")

        let scanner = ResidualFileScanner()
        let found = await scanner.scanResiduals(for: app(), homeDirectory: home.path)

        let cacheCandidate = try #require(found.first { $0.path == cachesDir.path })
        #expect(cacheCandidate.tier == .safe)
        #expect((cacheCandidate.sizeBytes ?? 0) > 0)
    }

    @Test("never matches another app's residual with a similar but distinct bundle identifier")
    func doesNotMatchDifferentApp() async throws {
        let home = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(home) }
        // A folder for a *different* (if similarly named) bundle id must
        // never be attributed to the app being uninstalled.
        let otherAppCaches = home.appendingPathComponent("Library/Caches/com.example.app.helper", isDirectory: true)
        try fm.createDirectory(at: otherAppCaches, withIntermediateDirectories: true)

        let scanner = ResidualFileScanner()
        let found = await scanner.scanResiduals(for: app(bundleIdentifier: "com.example.app"), homeDirectory: home.path)

        #expect(found.isEmpty)
    }

    @Test("locations that do not exist on disk are simply absent, not reported as missing/failed")
    func absentLocationsAreOmitted() async throws {
        let home = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(home) }
        // Nothing created under `home` at all.

        let scanner = ResidualFileScanner()
        let found = await scanner.scanResiduals(for: app(), homeDirectory: home.path)

        #expect(found.isEmpty)
    }

    @Test("does not double-report when a bundle-id-keyed and name-keyed rule resolve to the same path")
    func deduplicatesCoincidentPaths() async throws {
        let home = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(home) }
        // Contrive an app whose display name equals its bundle identifier,
        // so the two Application Support rules compute an identical path.
        let sameNameApp = app(bundleIdentifier: "SameName", displayName: "SameName")
        let supportDir = home.appendingPathComponent("Library/Application Support/SameName", isDirectory: true)
        try fm.createDirectory(at: supportDir, withIntermediateDirectories: true)

        let scanner = ResidualFileScanner()
        let found = await scanner.scanResiduals(for: sameNameApp, homeDirectory: home.path)

        #expect(found.filter { $0.path == supportDir.path }.count == 1)
    }

    @Test("a Containers match is reported with the destructive tier so it is never auto-selected")
    func containersMatchIsDestructiveTier() async throws {
        let home = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(home) }
        let containerDir = home.appendingPathComponent("Library/Containers/com.example.app", isDirectory: true)
        try fm.createDirectory(at: containerDir, withIntermediateDirectories: true)

        let scanner = ResidualFileScanner()
        let found = await scanner.scanResiduals(for: app(), homeDirectory: home.path)

        let containerCandidate = try #require(found.first { $0.path == containerDir.path })
        #expect(containerCandidate.tier == .destructive)
        #expect(!containerCandidate.tier.isDefaultSelectable)
    }

    @Test("a Preferences match uses the .plist suffix, not a bare bundle-id directory")
    func preferencesMatchesPlistFile() async throws {
        let home = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(home) }
        try fm.createDirectory(at: home.appendingPathComponent("Library/Preferences"), withIntermediateDirectories: true)
        let plistPath = home.appendingPathComponent("Library/Preferences/com.example.app.plist")
        try TestFixtures.writeFile(at: plistPath, contents: "fake plist")

        let scanner = ResidualFileScanner()
        let found = await scanner.scanResiduals(for: app(), homeDirectory: home.path)

        #expect(found.contains { $0.path == plistPath.path && $0.tier == .caution })
    }

    @Test("finds an exact <bundle id>.plist login item in LaunchAgents")
    func findsExactLaunchAgentPlist() async throws {
        let home = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(home) }
        try fm.createDirectory(at: home.appendingPathComponent("Library/LaunchAgents"), withIntermediateDirectories: true)
        let agentPath = home.appendingPathComponent("Library/LaunchAgents/com.example.app.plist")
        try TestFixtures.writeFile(at: agentPath, contents: "fake launch agent")

        let scanner = ResidualFileScanner()
        let found = await scanner.scanResiduals(for: app(), homeDirectory: home.path)

        let match = try #require(found.first { $0.path == agentPath.path })
        #expect(match.tier == .safe)
    }

    @Test("finds a helper agent named <bundle id>.<suffix>.plist in LaunchAgents")
    func findsHelperLaunchAgentPlist() async throws {
        let home = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(home) }
        try fm.createDirectory(at: home.appendingPathComponent("Library/LaunchAgents"), withIntermediateDirectories: true)
        let agentPath = home.appendingPathComponent("Library/LaunchAgents/com.example.app.helper.plist")
        try TestFixtures.writeFile(at: agentPath, contents: "fake launch agent")

        let scanner = ResidualFileScanner()
        let found = await scanner.scanResiduals(for: app(), homeDirectory: home.path)

        #expect(found.contains { $0.path == agentPath.path })
    }

    @Test("never matches a different app whose bundle id is a raw text prefix of the one being uninstalled")
    func doesNotMatchLaunchAgentOfPrefixedDifferentApp() async throws {
        let home = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(home) }
        try fm.createDirectory(at: home.appendingPathComponent("Library/LaunchAgents"), withIntermediateDirectories: true)
        // "com.example.app.helper" is a different, unrelated app whose id
        // happens to start with "com.example.app" as a raw string — but
        // NOT followed by a "." immediately, so it must never match when
        // uninstalling "com.example.app" itself.
        let unrelatedAgent = home.appendingPathComponent("Library/LaunchAgents/com.example.apphelper.plist")
        try TestFixtures.writeFile(at: unrelatedAgent, contents: "unrelated agent")

        let scanner = ResidualFileScanner()
        let found = await scanner.scanResiduals(for: app(bundleIdentifier: "com.example.app"), homeDirectory: home.path)

        #expect(found.isEmpty)
    }

    @Test("ignores non-plist files in LaunchAgents even if the name matches")
    func ignoresNonPlistFilesInLaunchAgents() async throws {
        let home = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(home) }
        try fm.createDirectory(at: home.appendingPathComponent("Library/LaunchAgents"), withIntermediateDirectories: true)
        try TestFixtures.writeFile(at: home.appendingPathComponent("Library/LaunchAgents/com.example.app.txt"), contents: "not a plist")

        let scanner = ResidualFileScanner()
        let found = await scanner.scanResiduals(for: app(), homeDirectory: home.path)

        #expect(found.isEmpty)
    }
}
