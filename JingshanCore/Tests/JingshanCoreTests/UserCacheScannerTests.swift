import Foundation
import Testing

@testable import JingshanCore

@Suite("UserCacheScanner")
struct UserCacheScannerTests {
    @Test("lists subfolders, tags bundle-identifier-looking names, and skips noise")
    func listsSubfoldersAndTagsBundleIdentifiers() async throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }

        let bundleFolder = scratch.appendingPathComponent("com.example.App", isDirectory: true)
        try FileManager.default.createDirectory(at: bundleFolder, withIntermediateDirectories: true)
        try TestFixtures.writeFile(at: bundleFolder.appendingPathComponent("cache.db"), contents: "0123456789")

        let plainFolder = scratch.appendingPathComponent("SomeCache", isDirectory: true)
        try FileManager.default.createDirectory(at: plainFolder, withIntermediateDirectories: true)

        try TestFixtures.writeFile(at: scratch.appendingPathComponent(".DS_Store"), contents: "noise")

        let scanner = UserCacheScanner(directoryPath: scratch.path, excludedNames: [])
        let category = await scanner.scan()

        #expect(category.id == "userCaches")
        #expect(category.items.count == 2)

        let bundleItem = try #require(category.items.first { $0.path == bundleFolder.path })
        #expect(bundleItem.ownerAppBundleID == "com.example.App")
        #expect(bundleItem.sizeBytes == 10)

        let plainItem = try #require(category.items.first { $0.path == plainFolder.path })
        #expect(plainItem.ownerAppBundleID == nil)

        #expect(!category.items.contains { $0.path.hasSuffix(".DS_Store") })
    }

    @Test("honors excludedNames so browser cache folders are not double-listed")
    func honorsExcludedNames() async throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }

        let safariFolder = scratch.appendingPathComponent("com.apple.Safari", isDirectory: true)
        try FileManager.default.createDirectory(at: safariFolder, withIntermediateDirectories: true)
        let otherFolder = scratch.appendingPathComponent("com.example.App", isDirectory: true)
        try FileManager.default.createDirectory(at: otherFolder, withIntermediateDirectories: true)

        let scanner = UserCacheScanner(directoryPath: scratch.path, excludedNames: ["com.apple.Safari"])
        let category = await scanner.scan()

        #expect(category.items.count == 1)
        #expect(category.items.first?.path == otherFolder.path)
    }

    @Test("default exclusion list also excludes the SwiftPM and Homebrew folders DevToolCacheScanner owns")
    func defaultExclusionListExcludesDevToolCacheOwnedFolders() async throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }

        try FileManager.default.createDirectory(
            at: scratch.appendingPathComponent("org.swift.swiftpm", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: scratch.appendingPathComponent("Homebrew", isDirectory: true),
            withIntermediateDirectories: true
        )
        let otherFolder = scratch.appendingPathComponent("com.example.App", isDirectory: true)
        try FileManager.default.createDirectory(at: otherFolder, withIntermediateDirectories: true)

        // Deliberately uses the *default* excludedNames (no override): a
        // prior version of this default only unioned browser-owned names
        // and missed the dev-tool-owned ones, causing SwiftPM/Homebrew to
        // be listed — and their size double-counted — under both "用户缓存"
        // and "开发工具缓存" at once.
        let scanner = UserCacheScanner(directoryPath: scratch.path)
        let category = await scanner.scan()

        #expect(category.items.count == 1)
        #expect(category.items.first?.path == otherFolder.path)
    }

    @Test("returns an empty category when the directory does not exist")
    func emptyWhenMissing() async throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }
        let missing = scratch.appendingPathComponent("does-not-exist").path

        let scanner = UserCacheScanner(directoryPath: missing)
        let category = await scanner.scan()

        #expect(category.items.isEmpty)
    }
}
