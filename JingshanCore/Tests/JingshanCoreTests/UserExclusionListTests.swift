import Foundation
import Testing

@testable import JingshanCore

@Suite("UserExclusionList")
struct UserExclusionListTests {
    @Test("contains matches an excluded path and anything nested under it")
    func containsMatchesSelfAndDescendants() {
        let list = UserExclusionList(excludedPaths: ["/Users/me/Library/Caches/com.example.App"])
        #expect(list.contains(resolvedPath: "/Users/me/Library/Caches/com.example.App"))
        #expect(list.contains(resolvedPath: "/Users/me/Library/Caches/com.example.App/Cache.db"))
        #expect(!list.contains(resolvedPath: "/Users/me/Library/Caches/com.example.AppOther"))
    }

    @Test("round-trips through save and load")
    func saveAndLoadRoundTrip() throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }
        let url = scratch.appendingPathComponent("exclusions.json")

        let original = UserExclusionList(
            excludedPaths: ["/Users/me/Library/Caches/com.example.App"],
            excludedBundleIdentifiers: ["com.example.App"]
        )
        try original.save(to: url)

        let loaded = try UserExclusionList.load(from: url)
        #expect(loaded == original)
    }

    @Test("loading a missing file returns an empty list rather than throwing")
    func loadMissingFileReturnsEmpty() throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }
        let url = scratch.appendingPathComponent("does-not-exist.json")

        let loaded = try UserExclusionList.load(from: url)
        #expect(loaded == UserExclusionList())
    }
}
