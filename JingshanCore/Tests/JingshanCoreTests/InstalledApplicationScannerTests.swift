import Foundation
import Testing

@testable import JingshanCore

@Suite("InstalledApplicationScanner")
struct InstalledApplicationScannerTests {
    private let fm = FileManager.default

    private func makeFixtureApp(
        in root: URL,
        named appName: String,
        bundleIdentifier: String,
        displayName: String? = nil,
        version: String? = "1.0"
    ) throws -> URL {
        let appPath = root.appendingPathComponent("\(appName).app", isDirectory: true)
        try fm.createDirectory(at: appPath.appendingPathComponent("Contents"), withIntermediateDirectories: true)

        var entries = "<key>CFBundleIdentifier</key><string>\(bundleIdentifier)</string>"
        if let displayName {
            entries += "<key>CFBundleDisplayName</key><string>\(displayName)</string>"
        }
        if let version {
            entries += "<key>CFBundleShortVersionString</key><string>\(version)</string>"
        }
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>\(entries)</dict></plist>
        """
        try TestFixtures.writeFile(at: appPath.appendingPathComponent("Contents/Info.plist"), contents: plist)
        return appPath
    }

    @Test("reads bundle identifier, display name, and version from Info.plist")
    func readsMetadataFromInfoPlist() async throws {
        let root = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(root) }
        _ = try makeFixtureApp(in: root, named: "MyApp", bundleIdentifier: "com.example.myapp", displayName: "My App", version: "2.5.0")

        let scanner = InstalledApplicationScanner()
        let found = await scanner.scan(roots: [root.path])

        let app = try #require(found.first)
        #expect(app.bundleIdentifier == "com.example.myapp")
        #expect(app.displayName == "My App")
        #expect(app.versionString == "2.5.0")
    }

    @Test("falls back to the folder name when Info.plist has no display name")
    func fallsBackToFolderName() async throws {
        let root = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(root) }
        _ = try makeFixtureApp(in: root, named: "NoDisplayName", bundleIdentifier: "com.example.nodisplayname", displayName: nil)

        let scanner = InstalledApplicationScanner()
        let found = await scanner.scan(roots: [root.path])

        #expect(found.first?.displayName == "NoDisplayName")
    }

    @Test("ignores entries that are not .app bundles")
    func ignoresNonAppEntries() async throws {
        let root = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(root) }
        _ = try makeFixtureApp(in: root, named: "RealApp", bundleIdentifier: "com.example.realapp")
        try fm.createDirectory(at: root.appendingPathComponent("Utilities"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("Python 3.14"), withIntermediateDirectories: true)

        let scanner = InstalledApplicationScanner()
        let found = await scanner.scan(roots: [root.path])

        #expect(found.count == 1)
        #expect(found.first?.bundleIdentifier == "com.example.realapp")
    }

    @Test("skips a .app whose Info.plist is missing or unreadable, without crashing")
    func skipsUnreadableBundle() async throws {
        let root = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(root) }
        try fm.createDirectory(at: root.appendingPathComponent("Broken.app/Contents"), withIntermediateDirectories: true)
        // Deliberately no Info.plist written.

        let scanner = InstalledApplicationScanner()
        let found = await scanner.scan(roots: [root.path])

        #expect(found.isEmpty)
    }

    @Test("never lists an app whose bundle identifier is on the protected allowlist")
    func excludesProtectedApps() async throws {
        let root = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(root) }
        _ = try makeFixtureApp(in: root, named: "SomeAppleTool", bundleIdentifier: "com.apple.someinternaltool")
        _ = try makeFixtureApp(in: root, named: "净山", bundleIdentifier: "net.kongshan.jingshan")
        _ = try makeFixtureApp(in: root, named: "RegularApp", bundleIdentifier: "com.example.regularapp")

        let scanner = InstalledApplicationScanner()
        let found = await scanner.scan(roots: [root.path])

        // Both the Apple wildcard match and Jingshan itself must be
        // filtered out at scan time — an uninstall candidate list should
        // never even offer them, not merely refuse them later.
        #expect(found.count == 1)
        #expect(found.first?.bundleIdentifier == "com.example.regularapp")
    }

    @Test("rejects a bundle identifier containing a path separator, instead of trusting it verbatim")
    func rejectsPathUnsafeBundleIdentifier() async throws {
        let root = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(root) }
        // A crafted CFBundleIdentifier is later interpolated into residual
        // paths (`Library/Caches/<bundle id>`); if it were trusted verbatim
        // here, a value like this would make that path escape to `/etc`
        // before `PathValidator` ever gets a chance to reject it.
        _ = try makeFixtureApp(in: root, named: "Malicious", bundleIdentifier: "../../../etc")

        let scanner = InstalledApplicationScanner()
        let found = await scanner.scan(roots: [root.path])

        #expect(found.isEmpty)
    }

    @Test("falls back to the folder name when CFBundleDisplayName is path-unsafe")
    func fallsBackWhenDisplayNameIsPathUnsafe() async throws {
        let root = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(root) }
        _ = try makeFixtureApp(in: root, named: "WeirdName", bundleIdentifier: "com.example.weirdname", displayName: "../../../etc")

        let scanner = InstalledApplicationScanner()
        let found = await scanner.scan(roots: [root.path])

        #expect(found.first?.displayName == "WeirdName")
    }

    @Test("computes a non-nil size for a discovered app")
    func computesSize() async throws {
        let root = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(root) }
        let app = try makeFixtureApp(in: root, named: "SizedApp", bundleIdentifier: "com.example.sizedapp")
        try fm.createDirectory(at: app.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
        try TestFixtures.writeFile(at: app.appendingPathComponent("Contents/MacOS/binary"), contents: "fake binary payload")

        let scanner = InstalledApplicationScanner()
        let found = await scanner.scan(roots: [root.path])

        let sizeBytes = try #require(found.first?.sizeBytes)
        #expect(sizeBytes > 0)
    }

    @Test("returns nothing for a root that does not exist")
    func emptyWhenRootMissing() async throws {
        let root = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(root) }
        let missing = root.appendingPathComponent("does-not-exist").path

        let scanner = InstalledApplicationScanner()
        let found = await scanner.scan(roots: [missing])
        #expect(found.isEmpty)
    }

    @Test("defaultRoots always includes /Applications and only includes ~/Applications when present")
    func defaultRootsReflectsHomeApplicationsExistence() {
        #expect(InstalledApplicationScanner.defaultRoots().contains("/Applications"))
    }
}
