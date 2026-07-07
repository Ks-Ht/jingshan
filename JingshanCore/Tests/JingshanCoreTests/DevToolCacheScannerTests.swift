import Foundation
import Testing

@testable import JingshanCore

@Suite("DevToolCacheScanner")
struct DevToolCacheScannerTests {
    @Test("only lists dev tool caches that actually exist on disk")
    func onlyListsExistingLocations() async throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }

        let derivedData = scratch.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true)
        try FileManager.default.createDirectory(at: derivedData, withIntermediateDirectories: true)
        try TestFixtures.writeFile(at: derivedData.appendingPathComponent("build.log"), contents: "1234567890")

        // Every other candidate location is intentionally left absent.

        let scanner = DevToolCacheScanner(homeDirectory: scratch.path)
        let category = await scanner.scan()

        #expect(category.items.count == 1)
        #expect(category.items.first?.resolvedDisplayLabel == "Xcode DerivedData")
        // Actual on-disk allocation (block-rounded), not logical bytes.
        #expect(category.items.first?.sizeBytes == FileSizeCalculator.allocatedSize(ofPath: derivedData.appendingPathComponent("build.log").path))
    }
}
