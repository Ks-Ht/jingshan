import Foundation
import Testing

@testable import JingshanCore

@Suite("PathValidator")
struct PathValidatorTests {
    @Test("rejects relative paths")
    func rejectsRelativePath() {
        let validator = PathValidator()
        let result = validator.validate("Library/Caches/foo")
        #expect(result == .failure(.notAbsolute("Library/Caches/foo")))
    }

    @Test("rejects literal .. traversal components")
    func rejectsTraversal() {
        let validator = PathValidator()
        let path = "/Users/someone/../../etc/passwd"
        let result = validator.validate(path)
        #expect(result == .failure(.containsTraversal(path)))
    }

    @Test("rejects embedded control characters")
    func rejectsControlCharacters() {
        let validator = PathValidator()
        let path = "/Users/someone/Library/Caches/foo\nbar"
        let result = validator.validate(path)
        #expect(result == .failure(.containsControlCharacters(path)))
    }

    @Test("does not reject a real directory name that merely contains ..")
    func allowsDotDotInsideARealName() throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }

        let dotDotNamed = scratch.appendingPathComponent("name..files", isDirectory: true)
        try FileManager.default.createDirectory(at: dotDotNamed, withIntermediateDirectories: true)

        let validator = PathValidator()
        let result = validator.validate(dotDotNamed.path)
        #expect(result.isSuccess)
    }

    @Test(
        "matches the critical denylist by exact path and by directory prefix",
        arguments: [
            ("/etc", true),
            ("/etc/passwd", true),
            ("/System", true),
            ("/System/Library", true),
            ("/private", true),
            ("/Applications", true),
        ]
    )
    func matchesDenylist(path: String, shouldMatch: Bool) {
        let match = CriticalPathDenylist.default.firstMatch(forResolvedPath: path)
        #expect((match != nil) == shouldMatch)
    }

    @Test("denylist matching is case-insensitive")
    func denylistIsCaseInsensitive() {
        #expect(CriticalPathDenylist.default.firstMatch(forResolvedPath: "/system/library") != nil)
        #expect(CriticalPathDenylist.default.firstMatch(forResolvedPath: "/ETC/passwd") != nil)
    }

    @Test("rejects a resolved path under a hard-denylisted directory")
    func rejectsPathUnderDenylist() {
        let validator = PathValidator()
        let result = validator.validate("/etc/passwd")
        guard case .failure(.matchesCriticalDenylist) = result else {
            Issue.record("expected matchesCriticalDenylist, got \(result)")
            return
        }
    }

    @Test("rejects a symlink that resolves into a denylisted directory")
    func rejectsSymlinkEscape() throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }

        let looksInnocent = scratch.appendingPathComponent("innocent-cache-entry")
        try FileManager.default.createSymbolicLink(at: looksInnocent, withDestinationURL: URL(fileURLWithPath: "/etc/passwd"))

        let validator = PathValidator()
        let result = validator.validate(looksInnocent.path)
        guard case .failure(.matchesCriticalDenylist) = result else {
            Issue.record("expected the symlink target to be caught by the denylist, got \(result)")
            return
        }
    }

    @Test("rejects a multi-hop symlink chain that ends in a denylisted directory")
    func rejectsMultiHopSymlinkEscape() throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }

        let hopOne = scratch.appendingPathComponent("hop-one")
        let hopTwo = scratch.appendingPathComponent("hop-two")
        try FileManager.default.createSymbolicLink(at: hopTwo, withDestinationURL: URL(fileURLWithPath: "/etc"))
        try FileManager.default.createSymbolicLink(at: hopOne, withDestinationURL: hopTwo)

        let validator = PathValidator()
        let result = validator.validate(hopOne.path)
        guard case .failure(.matchesCriticalDenylist) = result else {
            Issue.record("expected the multi-hop symlink target to be caught by the denylist, got \(result)")
            return
        }
    }

    @Test("rejects the user's home directory root itself")
    func rejectsHomeDirectoryRoot() {
        let home = NSHomeDirectory()
        let validator = PathValidator(homeDirectory: home)
        let result = validator.validate(home)
        #expect(result == .failure(.isUserHomeRoot(PathValidator.normalize(home))))
    }

    @Test("allows a child path inside the home directory")
    func allowsChildOfHomeDirectory() throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }

        let validator = PathValidator()
        let result = validator.validate(scratch.path)
        #expect(result.isSuccess)
    }

    @Test("reports a path that does not exist")
    func reportsNonexistentPath() throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }

        let missing = scratch.appendingPathComponent("does-not-exist").path
        let validator = PathValidator()
        let result = validator.validate(missing)
        #expect(result == .failure(.pathDoesNotExist(missing)))
    }

    @Test("still validates a broken symlink (the link itself exists even though its target is gone)")
    func allowsBrokenSymlinkAsDeletionTarget() throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }

        let target = scratch.appendingPathComponent("will-be-removed")
        try TestFixtures.writeFile(at: target)
        let brokenLink = scratch.appendingPathComponent("broken-link")
        try FileManager.default.createSymbolicLink(at: brokenLink, withDestinationURL: target)
        try FileManager.default.removeItem(at: target)

        let validator = PathValidator()
        let result = validator.validate(brokenLink.path)
        #expect(result.isSuccess)
    }
}

extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
