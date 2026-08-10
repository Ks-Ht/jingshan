import Foundation
import Testing

@testable import JingshanCore

@Suite("BrowserCacheScanner")
struct BrowserCacheScannerTests {
    @Test("only lists browser cache locations that actually exist, with a friendly label and bundle id")
    func onlyListsExistingLocations() async throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }

        let safariCache = scratch.appendingPathComponent("Library/Caches/com.apple.Safari", isDirectory: true)
        try FileManager.default.createDirectory(at: safariCache, withIntermediateDirectories: true)
        try TestFixtures.writeFile(at: safariCache.appendingPathComponent("a.db"), contents: "12345")

        // Chrome's cache directory is intentionally left absent.

        let scanner = BrowserCacheScanner(homeDirectory: scratch.path)
        let category = await scanner.scan()

        #expect(category.items.count == 1)
        let item = try #require(category.items.first)
        #expect(item.resolvedDisplayLabel == "Safari")
        #expect(item.ownerAppBundleID == "com.apple.Safari")
        // Actual on-disk allocation (block-rounded), not logical bytes.
        #expect(item.sizeBytes == FileSizeCalculator.allocatedSize(ofPath: safariCache.appendingPathComponent("a.db").path))
    }

    @Test("reports an empty category when no known browser is installed")
    func emptyWhenNoneInstalled() async throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }

        let scanner = BrowserCacheScanner(homeDirectory: scratch.path)
        let category = await scanner.scan()

        #expect(category.items.isEmpty)
    }

    @Test("只发现 Chromium profile 中的已知缓存子目录")
    func findsKnownChromiumProfileCaches() async throws {
        let home = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(home) }
        let profile = home.appendingPathComponent("Library/Application Support/Google/Chrome/Profile 1")
        let codeCache = profile.appendingPathComponent("Code Cache")
        try FileManager.default.createDirectory(at: codeCache, withIntermediateDirectories: true)
        try TestFixtures.writeFile(at: codeCache.appendingPathComponent("compiled.js"), contents: "cache")
        try TestFixtures.writeFile(at: profile.appendingPathComponent("History"), contents: "keep")

        let category = await BrowserCacheScanner(homeDirectory: home.path).scan()

        #expect(category.items.contains { $0.path == codeCache.path })
        #expect(!category.items.contains { $0.path.hasSuffix("History") })
    }

    @Test("存在但无法读取的 Chromium 数据根会报告扫描问题")
    func reportsUnreadableChromiumRoot() async throws {
        let home = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(home) }
        let root = home.appendingPathComponent("Library/Application Support/Google/Chrome")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: root.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path) }

        let category = await BrowserCacheScanner(homeDirectory: home.path).scan()

        #expect(!category.issues.isEmpty)
    }
}
