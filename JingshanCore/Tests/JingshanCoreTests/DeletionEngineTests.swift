import Foundation
import Testing

@testable import JingshanCore

@Suite("DeletionEngine")
struct DeletionEngineTests {
    private func makeEngine(
        scratch: URL,
        exclusions: UserExclusionList = UserExclusionList(),
        protectedApps: ProtectedAppAllowlist = .default,
        runningChecker: RunningApplicationChecking = FakeRunningApplicationChecker(),
        logger: InMemoryOperationLogger = InMemoryOperationLogger()
    ) -> DeletionEngine {
        DeletionEngine(
            protectedApps: protectedApps,
            exclusions: exclusions,
            runningChecker: runningChecker,
            logger: logger,
            trashMover: FakeTrashMover(trashDirectory: scratch.appendingPathComponent("fake-trash"))
        )
    }

    @Test("moves the fixture into the (fake) trash and reports a size")
    func trashModeMovesFile() throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }
        let file = scratch.appendingPathComponent("cache-entry.tmp")
        try TestFixtures.writeFile(at: file)

        let logger = InMemoryOperationLogger()
        let engine = makeEngine(scratch: scratch, logger: logger)

        let outcome = engine.delete(path: file.path, mode: .trash)

        guard case .movedToTrash(_, let resultingURL, let sizeBytes) = outcome else {
            Issue.record("expected movedToTrash, got \(outcome)")
            return
        }
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(resultingURL != nil)
        if let resultingURL {
            #expect(FileManager.default.fileExists(atPath: resultingURL.path))
        }
        #expect(sizeBytes != nil)
        #expect(logger.entries.contains { $0.outcome == "moved_to_trash" })
    }

    @Test("refuses a permanent delete when not explicitly confirmed")
    func permanentDeleteRefusedWithoutConfirmation() throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }
        let file = scratch.appendingPathComponent("cache-entry.tmp")
        try TestFixtures.writeFile(at: file)

        let logger = InMemoryOperationLogger()
        let engine = makeEngine(scratch: scratch, logger: logger)

        let outcome = engine.delete(path: file.path, mode: .permanent(confirmed: false))

        #expect(outcome == .failed(originalPath: file.path, error: .permanentDeleteNotConfirmed))
        #expect(FileManager.default.fileExists(atPath: file.path))
        #expect(logger.entries.contains { $0.outcome == "refused_unconfirmed" })
    }

    @Test("permanently deletes once explicitly confirmed")
    func permanentDeleteWithConfirmationRemoves() throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }
        let file = scratch.appendingPathComponent("cache-entry.tmp")
        try TestFixtures.writeFile(at: file)

        let logger = InMemoryOperationLogger()
        let engine = makeEngine(scratch: scratch, logger: logger)

        let outcome = engine.delete(path: file.path, mode: .permanent(confirmed: true))

        guard case .permanentlyDeleted = outcome else {
            Issue.record("expected permanentlyDeleted, got \(outcome)")
            return
        }
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(logger.entries.contains { $0.outcome == "permanently_deleted" })
    }

    @Test("honors an excluded path and leaves the file untouched")
    func exclusionListHonorsPath() throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }
        let file = scratch.appendingPathComponent("cache-entry.tmp")
        try TestFixtures.writeFile(at: file)

        let logger = InMemoryOperationLogger()
        let exclusions = UserExclusionList(excludedPaths: [file.path])
        let engine = makeEngine(scratch: scratch, exclusions: exclusions, logger: logger)

        let outcome = engine.delete(path: file.path, mode: .trash)

        guard case .skippedExcluded = outcome else {
            Issue.record("expected skippedExcluded, got \(outcome)")
            return
        }
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test("honors an exclusion stored as an unresolved symlink path even though the item resolves elsewhere")
    func exclusionListHonorsSymlinkExclusion() throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }

        // Real target the user actually wants deleted-protected, plus a
        // symlink the user picked in Settings (stored unresolved).
        let target = scratch.appendingPathComponent("real-cache")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let symlink = scratch.appendingPathComponent("cache-link")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: target)

        // The user excluded the symlink path (unresolved). The engine, which
        // deletes by the symlink but validates/resolves it, must still honor
        // the exclusion — this is the defense-in-depth gap the audit caught.
        let exclusions = UserExclusionList(excludedPaths: [symlink.path])
        let engine = makeEngine(scratch: scratch, exclusions: exclusions)

        let outcome = engine.delete(path: symlink.path, mode: .trash)

        guard case .skippedExcluded = outcome else {
            Issue.record("expected skippedExcluded for a symlink exclusion, got \(outcome)")
            return
        }
        #expect(FileManager.default.fileExists(atPath: symlink.path))
    }

    @Test("honors an excluded bundle identifier even when the path itself is not excluded")
    func exclusionListHonorsBundleIdentifier() throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }
        let file = scratch.appendingPathComponent("cache-entry.tmp")
        try TestFixtures.writeFile(at: file)

        let logger = InMemoryOperationLogger()
        let exclusions = UserExclusionList(excludedBundleIdentifiers: ["com.example.App"])
        let engine = makeEngine(scratch: scratch, exclusions: exclusions, logger: logger)

        let outcome = engine.delete(path: file.path, mode: .trash, associatedBundleIdentifier: "com.example.App")

        guard case .skippedExcluded = outcome else {
            Issue.record("expected skippedExcluded, got \(outcome)")
            return
        }
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test("skips a running app's data by default, but allows an explicit override")
    func protectedRunningAppSkippedByDefaultAndOverridable() throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }
        let file = scratch.appendingPathComponent("cache-entry.tmp")
        try TestFixtures.writeFile(at: file)

        let logger = InMemoryOperationLogger()
        let runningChecker = FakeRunningApplicationChecker(runningBundleIdentifiers: ["com.example.RunningApp"])
        let engine = makeEngine(scratch: scratch, runningChecker: runningChecker, logger: logger)

        let defaultOutcome = engine.delete(path: file.path, mode: .trash, associatedBundleIdentifier: "com.example.RunningApp")
        guard case .skippedProtectedApp = defaultOutcome else {
            Issue.record("expected skippedProtectedApp, got \(defaultOutcome)")
            return
        }
        #expect(FileManager.default.fileExists(atPath: file.path))

        let overriddenOutcome = engine.delete(
            path: file.path,
            mode: .trash,
            associatedBundleIdentifier: "com.example.RunningApp",
            allowProtectedAppOverride: true
        )
        guard case .movedToTrash = overriddenOutcome else {
            Issue.record("expected movedToTrash after override, got \(overriddenOutcome)")
            return
        }
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test("never allows overriding the static protected-app allowlist")
    func staticAllowlistIsNeverOverridable() throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }
        let file = scratch.appendingPathComponent("cache-entry.tmp")
        try TestFixtures.writeFile(at: file)

        let logger = InMemoryOperationLogger()
        let protectedApps = ProtectedAppAllowlist(entries: [
            .init(bundleIdentifierPattern: "com.apple.*", reason: "test")
        ])
        let engine = makeEngine(scratch: scratch, protectedApps: protectedApps, logger: logger)

        let outcome = engine.delete(
            path: file.path,
            mode: .trash,
            associatedBundleIdentifier: "com.apple.Safari",
            allowProtectedAppOverride: true
        )

        guard case .skippedProtectedApp = outcome else {
            Issue.record("expected skippedProtectedApp even with override, got \(outcome)")
            return
        }
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test("treats a nonexistent path as a benign no-op, not a failure")
    func alreadyAbsentIsNotAFailure() throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }
        let missing = scratch.appendingPathComponent("never-existed.tmp").path

        let logger = InMemoryOperationLogger()
        let engine = makeEngine(scratch: scratch, logger: logger)

        let outcome = engine.delete(path: missing, mode: .trash)
        #expect(outcome == .alreadyAbsent(originalPath: missing))
        #expect(logger.entries.contains { $0.outcome == "already_absent" })
    }

    @Test("reports and logs a validation failure without touching the filesystem")
    func validationFailureIsReportedAndLogged() throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }

        let logger = InMemoryOperationLogger()
        let engine = makeEngine(scratch: scratch, logger: logger)

        let outcome = engine.delete(path: "relative/path", mode: .trash)

        #expect(outcome == .failed(originalPath: "relative/path", error: .validationFailed(.notAbsolute("relative/path"))))
        #expect(logger.entries.contains { $0.outcome == "validation_failed" })
    }

    @Test("refuses to delete a path under the critical denylist regardless of mode")
    func refusesCriticalPath() throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }

        let logger = InMemoryOperationLogger()
        let engine = makeEngine(scratch: scratch, logger: logger)

        let outcome = engine.delete(path: "/etc/passwd", mode: .permanent(confirmed: true))

        guard case .failed(_, .validationFailed(.matchesCriticalDenylist)) = outcome else {
            Issue.record("expected a validationFailed(.matchesCriticalDenylist) failure, got \(outcome)")
            return
        }
    }
}
