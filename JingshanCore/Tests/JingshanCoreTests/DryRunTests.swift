import Foundation
import Testing

@testable import JingshanCore

@Suite("DeletionEngine dry run")
struct DryRunTests {
    @Test("dry run never mutates the filesystem but still logs an entry")
    func dryRunDoesNotMutateButLogs() throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }
        let file = scratch.appendingPathComponent("cache-entry.tmp")
        try TestFixtures.writeFile(at: file)

        let logger = InMemoryOperationLogger()
        let engine = DeletionEngine(logger: logger, trashMover: FakeTrashMover(trashDirectory: scratch.appendingPathComponent("trash")))

        let outcome = engine.delete(path: file.path, mode: .dryRun)

        guard case .wouldDelete(_, let sizeBytes) = outcome else {
            Issue.record("expected wouldDelete, got \(outcome)")
            return
        }
        #expect(sizeBytes != nil)
        #expect(FileManager.default.fileExists(atPath: file.path))
        #expect(logger.entries.contains { $0.outcome == "would_delete" })
    }

    @Test("dry run does not move anything into the trash directory")
    func dryRunDoesNotTouchTrash() throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }
        let file = scratch.appendingPathComponent("cache-entry.tmp")
        try TestFixtures.writeFile(at: file)
        let trashDirectory = scratch.appendingPathComponent("trash")

        let logger = InMemoryOperationLogger()
        let engine = DeletionEngine(logger: logger, trashMover: FakeTrashMover(trashDirectory: trashDirectory))

        _ = engine.delete(path: file.path, mode: .dryRun)

        let trashContents = (try? FileManager.default.contentsOfDirectory(atPath: trashDirectory.path)) ?? []
        #expect(trashContents.isEmpty)
    }

    @Test("dry run on an excluded path is still reported as skipped, not as would-delete")
    func dryRunRespectsExclusions() throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }
        let file = scratch.appendingPathComponent("cache-entry.tmp")
        try TestFixtures.writeFile(at: file)

        let logger = InMemoryOperationLogger()
        let exclusions = UserExclusionList(excludedPaths: [file.path])
        let engine = DeletionEngine(
            exclusions: exclusions,
            logger: logger,
            trashMover: FakeTrashMover(trashDirectory: scratch.appendingPathComponent("trash"))
        )

        let outcome = engine.delete(path: file.path, mode: .dryRun)

        guard case .skippedExcluded = outcome else {
            Issue.record("expected skippedExcluded, got \(outcome)")
            return
        }
    }
}
