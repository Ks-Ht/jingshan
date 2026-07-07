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
}
