import Foundation
import Testing

@testable import JingshanCore

/// The restore path is the only code in the app that moves user files back
/// out of the Trash — every safety property gets its own test.
@Suite("CleanupRestorer")
struct CleanupRestoreTests {
    private func makeWorld() throws -> (trash: URL, home: URL, cleanup: () -> Void) {
        let scratch = try TestFixtures.makeScratchDirectory()
        let trash = scratch.appendingPathComponent("Trash", isDirectory: true)
        let home = scratch.appendingPathComponent("home", isDirectory: true)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        return (trash, home, { TestFixtures.removeIfNeeded(scratch) })
    }

    @Test("restores a trashed file back to its original path")
    func restoresBack() throws {
        let world = try makeWorld()
        defer { world.cleanup() }
        let original = world.home.appendingPathComponent("notes.txt")
        let trashed = world.trash.appendingPathComponent("notes.txt")
        try TestFixtures.writeFile(at: trashed, contents: "hello")

        let item = TrashedItem(originalPath: original.path, trashPath: trashed.path).fingerprinted()
        let outcome = CleanupRestorer.restore([item], trashRoots: [world.trash.path])

        #expect(outcome.restoredCount == 1)
        #expect(outcome.failedCount == 0)
        #expect(outcome.remaining.isEmpty)
        #expect(FileManager.default.fileExists(atPath: original.path))
        #expect(!FileManager.default.fileExists(atPath: trashed.path))
    }

    @Test("never overwrites an occupied original path, and keeps the item retryable")
    func neverOverwrites() throws {
        let world = try makeWorld()
        defer { world.cleanup() }
        let original = world.home.appendingPathComponent("doc.txt")
        let trashed = world.trash.appendingPathComponent("doc.txt")
        try TestFixtures.writeFile(at: trashed, contents: "old")
        try TestFixtures.writeFile(at: original, contents: "NEW FILE — must survive")

        let item = TrashedItem(originalPath: original.path, trashPath: trashed.path).fingerprinted()
        let outcome = CleanupRestorer.restore([item], trashRoots: [world.trash.path])

        #expect(outcome.restoredCount == 0)
        #expect(outcome.failedCount == 1)
        #expect(outcome.remaining == [item]) // retryable once the user clears the spot
        #expect(try String(contentsOf: original, encoding: .utf8) == "NEW FILE — must survive")
        #expect(FileManager.default.fileExists(atPath: trashed.path)) // stays safely in Trash
    }

    @Test("refuses a source outside the Trash roots — tampered history can't become a move primitive")
    func refusesNonTrashSource() throws {
        let world = try makeWorld()
        defer { world.cleanup() }
        let outside = world.home.appendingPathComponent("secret.txt")
        try TestFixtures.writeFile(at: outside, contents: "s")
        let destination = world.home.appendingPathComponent("elsewhere/secret.txt")

        let item = TrashedItem(originalPath: destination.path, trashPath: outside.path)
        let outcome = CleanupRestorer.restore([item], trashRoots: [world.trash.path])

        #expect(outcome.restoredCount == 0)
        #expect(outcome.failedCount == 1)
        #expect(outcome.remaining.isEmpty) // unrestorable by construction — dropped
        #expect(FileManager.default.fileExists(atPath: outside.path)) // untouched
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test("refuses a Trash path whose ancestor symlink escapes the trusted root")
    func refusesAncestorSymlinkEscape() throws {
        let world = try makeWorld()
        defer { world.cleanup() }

        let protectedDirectory = world.home.appendingPathComponent("protected", isDirectory: true)
        try FileManager.default.createDirectory(at: protectedDirectory, withIntermediateDirectories: true)
        let protectedFile = protectedDirectory.appendingPathComponent("private.txt")
        try TestFixtures.writeFile(at: protectedFile, contents: "must stay put")

        let pivot = world.trash.appendingPathComponent("pivot")
        try FileManager.default.createSymbolicLink(at: pivot, withDestinationURL: protectedDirectory)
        let disguisedSource = pivot.appendingPathComponent("private.txt")
        let destination = world.home.appendingPathComponent("exfiltrated.txt")

        let item = TrashedItem(originalPath: destination.path, trashPath: disguisedSource.path).fingerprinted()
        let outcome = CleanupRestorer.restore([item], trashRoots: [world.trash.path])

        #expect(outcome.restoredCount == 0)
        #expect(outcome.failedCount == 1)
        #expect(outcome.remaining.isEmpty)
        #expect(FileManager.default.fileExists(atPath: protectedFile.path))
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test("restores a symlink item itself without following its target")
    func restoresSymlinkItem() throws {
        let world = try makeWorld()
        defer { world.cleanup() }

        let target = world.home.appendingPathComponent("target.txt")
        try TestFixtures.writeFile(at: target, contents: "target stays")
        let trashedLink = world.trash.appendingPathComponent("shortcut")
        try FileManager.default.createSymbolicLink(at: trashedLink, withDestinationURL: target)
        let restoredLink = world.home.appendingPathComponent("shortcut")

        let item = TrashedItem(originalPath: restoredLink.path, trashPath: trashedLink.path)
        let outcome = CleanupRestorer.restore([item], trashRoots: [world.trash.path])

        #expect(outcome.restoredCount == 1)
        #expect(FileManager.default.fileExists(atPath: target.path))
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: restoredLink.path)) != nil)
    }

    @Test("restores a dangling symlink item without following its missing target")
    func restoresDanglingSymlinkItem() throws {
        let world = try makeWorld()
        defer { world.cleanup() }

        let missingTarget = world.home.appendingPathComponent("missing-target")
        let trashedLink = world.trash.appendingPathComponent("dangling-shortcut")
        try FileManager.default.createSymbolicLink(at: trashedLink, withDestinationURL: missingTarget)
        let restoredLink = world.home.appendingPathComponent("dangling-shortcut")

        let item = TrashedItem(originalPath: restoredLink.path, trashPath: trashedLink.path).fingerprinted()
        let outcome = CleanupRestorer.restore([item], trashRoots: [world.trash.path])

        #expect(outcome.restoredCount == 1)
        #expect(outcome.failedCount == 0)
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: restoredLink.path)) != nil)
        #expect(!FileManager.default.fileExists(atPath: missingTarget.path))
    }

    @Test("never overwrites a dangling symlink at the original path")
    func neverOverwritesDanglingDestination() throws {
        let world = try makeWorld()
        defer { world.cleanup() }

        let original = world.home.appendingPathComponent("occupied-link")
        let missingTarget = world.home.appendingPathComponent("still-missing")
        try FileManager.default.createSymbolicLink(at: original, withDestinationURL: missingTarget)
        let trashed = world.trash.appendingPathComponent("occupied-link")
        try TestFixtures.writeFile(at: trashed, contents: "must stay in Trash")

        let item = TrashedItem(originalPath: original.path, trashPath: trashed.path).fingerprinted()
        let outcome = CleanupRestorer.restore([item], trashRoots: [world.trash.path])

        #expect(outcome.restoredCount == 0)
        #expect(outcome.failedCount == 1)
        #expect(outcome.remaining == [item])
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: original.path)) != nil)
        #expect(FileManager.default.fileExists(atPath: trashed.path))
    }

    @Test("refuses to restore a DIFFERENT file that re-occupied the same Trash path")
    func refusesFingerprintMismatch() throws {
        let world = try makeWorld()
        defer { world.cleanup() }
        let original = world.home.appendingPathComponent("movie.mkv")
        let trashed = world.trash.appendingPathComponent("movie.mkv")
        try TestFixtures.writeFile(at: trashed, contents: "original-bytes")
        let item = TrashedItem(originalPath: original.path, trashPath: trashed.path).fingerprinted()

        // Simulate: Trash emptied, then another same-named file trashed later.
        try FileManager.default.removeItem(at: trashed)
        try TestFixtures.writeFile(at: trashed, contents: "a completely different file!")

        let outcome = CleanupRestorer.restore([item], trashRoots: [world.trash.path])

        #expect(outcome.restoredCount == 0)
        #expect(outcome.failedCount == 1)
        #expect(outcome.remaining.isEmpty) // that file is gone for good — dropped
        #expect(!FileManager.default.fileExists(atPath: original.path)) // wrong file NOT moved
        #expect(FileManager.default.fileExists(atPath: trashed.path))   // impostor left alone
    }

    @Test("a source already gone from the Trash counts failed and is dropped")
    func missingSourceDropped() throws {
        let world = try makeWorld()
        defer { world.cleanup() }
        let item = TrashedItem(
            originalPath: world.home.appendingPathComponent("gone.txt").path,
            trashPath: world.trash.appendingPathComponent("gone.txt").path
        )
        let outcome = CleanupRestorer.restore([item], trashRoots: [world.trash.path])
        #expect(outcome.restoredCount == 0)
        #expect(outcome.failedCount == 1)
        #expect(outcome.remaining.isEmpty)
    }

    @Test("legacy records without a fingerprint still restore")
    func legacyItemsRestore() throws {
        let world = try makeWorld()
        defer { world.cleanup() }
        let original = world.home.appendingPathComponent("legacy.txt")
        let trashed = world.trash.appendingPathComponent("legacy.txt")
        try TestFixtures.writeFile(at: trashed, contents: "x")

        let item = TrashedItem(originalPath: original.path, trashPath: trashed.path) // no fingerprint
        let outcome = CleanupRestorer.restore([item], trashRoots: [world.trash.path])
        #expect(outcome.restoredCount == 1)
        #expect(FileManager.default.fileExists(atPath: original.path))
    }

    @Test("only accepts a Trash root that actually contains the source")
    func derivesTrustedExternalTrashRoot() {
        #expect(
            CleanupRestorer.trustedTrashRoot(
                trashPath: "/Volumes/Archive/.Trashes/501/cache.db",
                candidateRoot: "/Volumes/Archive/.Trashes/501"
            ) == "/Volumes/Archive/.Trashes/501"
        )
        #expect(
            CleanupRestorer.trustedTrashRoot(
                trashPath: "/tmp/.Trashes/501/cache.db",
                candidateRoot: "/Volumes/Archive/.Trashes/501"
            ) == nil
        )
    }
}
