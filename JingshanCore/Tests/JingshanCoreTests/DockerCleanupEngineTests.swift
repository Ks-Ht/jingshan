import Foundation
import Testing

@testable import JingshanCore

@Suite("DockerCleanupEngine")
struct DockerCleanupEngineTests {
    private func makeCommandItem(
        id: String = "container:abc123",
        kind: DockerResourceKind = .container,
        risk: DockerRiskLevel = .caution,
        arguments: [String] = ["rm", "abc123"]
    ) -> DockerCleanableItem {
        DockerCleanableItem(
            id: id,
            kind: kind,
            displayName: "my-container",
            detail: "detail",
            sizeBytes: 1024,
            risk: risk,
            riskNote: "note",
            defaultSelected: risk != .destructive,
            removal: .dockerCommand(arguments: arguments)
        )
    }

    private func makeFileItem(path: String, sizeBytes: Int64? = 2048) -> DockerCleanableItem {
        DockerCleanableItem(
            id: "hostDiskImage:\(path)",
            kind: .diskImage,
            displayName: "Docker 虚拟磁盘",
            detail: path,
            sizeBytes: sizeBytes,
            risk: .destructive,
            riskNote: "note",
            defaultSelected: false,
            removal: .filesystemPath(path)
        )
    }

    // MARK: - docker command items

    @Test("dry run never invokes the underlying docker command, but still logs")
    func dryRunNeverInvokesCommandButLogs() async {
        let runner = FakeDockerCommandRunner()
        let logger = InMemoryDockerOperationLogger()
        let engine = DockerCleanupEngine(commandRunner: runner, logger: logger)
        let item = makeCommandItem()

        let outcome = await engine.remove(item, mode: .dryRun)

        guard case .wouldRemove = outcome else {
            Issue.record("expected wouldRemove, got \(outcome)")
            return
        }
        #expect(runner.invokedArguments.isEmpty)
        #expect(logger.entries.contains { $0.outcome == "would_remove" })
    }

    @Test("real mode invokes the exact removal arguments and reports success")
    func realModeInvokesRemovalArgumentsAndSucceeds() async {
        let runner = FakeDockerCommandRunner()
        let logger = InMemoryDockerOperationLogger()
        let engine = DockerCleanupEngine(commandRunner: runner, logger: logger)
        let item = makeCommandItem(arguments: ["rm", "abc123"])
        runner.setSuccess(for: ["rm", "abc123"], output: "abc123\n")

        let outcome = await engine.remove(item, mode: .real)

        guard case .removed(_, let freedBytes) = outcome else {
            Issue.record("expected removed, got \(outcome)")
            return
        }
        #expect(freedBytes == item.sizeBytes)
        #expect(runner.invokedArguments == [["rm", "abc123"]])
        #expect(logger.entries.contains { $0.outcome == "removed" })
    }

    @Test("a failing docker command is reported as failed and logged with detail")
    func failingCommandIsReportedAndLogged() async {
        let runner = FakeDockerCommandRunner()
        let logger = InMemoryDockerOperationLogger()
        let engine = DockerCleanupEngine(commandRunner: runner, logger: logger)
        let item = makeCommandItem(arguments: ["rmi", "nginx:latest"])
        runner.setFailure(for: ["rmi", "nginx:latest"], error: DockerCommandError.processFailed(exitCode: 1, stderr: "image is being used by running container"))

        let outcome = await engine.remove(item, mode: .real)

        guard case .failed = outcome else {
            Issue.record("expected failed, got \(outcome)")
            return
        }
        let failedEntry = logger.entries.first { $0.outcome == "failed" }
        #expect(failedEntry != nil)
        #expect(failedEntry?.detail?.contains("being used") == true)
    }

    @Test("logged entries carry the resource kind, id, and a docker-prefixed audit trail")
    func loggedEntriesCarryFullContext() async {
        let runner = FakeDockerCommandRunner()
        let logger = InMemoryDockerOperationLogger()
        let engine = DockerCleanupEngine(commandRunner: runner, logger: logger)
        let item = makeCommandItem(id: "volume:old-db-data", kind: .volume, risk: .destructive, arguments: ["volume", "rm", "old-db-data"])
        runner.setSuccess(for: ["volume", "rm", "old-db-data"], output: "")

        _ = await engine.remove(item, mode: .real)

        let entry = try! #require(logger.entries.first)
        #expect(entry.resourceID == "volume:old-db-data")
        #expect(entry.kind == "volume")
        #expect(entry.arguments == ["docker", "volume", "rm", "old-db-data"])
    }

    // MARK: - filesystem-path items (host-side data)

    @Test("a host filesystem item is removed through the DeletionEngine (Trash), never the docker CLI")
    func filesystemItemRoutesThroughDeletionEngineAndTrash() async throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }
        let file = scratch.appendingPathComponent("Docker.raw")
        try TestFixtures.writeFile(at: file, contents: "0123456789")

        let runner = FakeDockerCommandRunner()
        let logger = InMemoryDockerOperationLogger()
        let deletionEngine = DeletionEngine(
            logger: InMemoryOperationLogger(),
            trashMover: FakeTrashMover(trashDirectory: scratch.appendingPathComponent("trash"))
        )
        let engine = DockerCleanupEngine(commandRunner: runner, deletionEngine: deletionEngine, logger: logger)

        let outcome = await engine.remove(makeFileItem(path: file.path), mode: .real)

        guard case .removed = outcome else {
            Issue.record("expected removed, got \(outcome)")
            return
        }
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(runner.invokedArguments.isEmpty)  // never touched the docker CLI
        let entry = try #require(logger.entries.first)
        #expect(entry.arguments.first == "trash-file")
    }

    @Test("dry run on a host filesystem item never mutates the file")
    func filesystemItemDryRunDoesNotMutate() async throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }
        let file = scratch.appendingPathComponent("Docker.raw")
        try TestFixtures.writeFile(at: file, contents: "0123456789")

        let deletionEngine = DeletionEngine(
            logger: InMemoryOperationLogger(),
            trashMover: FakeTrashMover(trashDirectory: scratch.appendingPathComponent("trash"))
        )
        let engine = DockerCleanupEngine(commandRunner: FakeDockerCommandRunner(), deletionEngine: deletionEngine, logger: InMemoryDockerOperationLogger())

        let outcome = await engine.remove(makeFileItem(path: file.path), mode: .dryRun)

        guard case .wouldRemove = outcome else {
            Issue.record("expected wouldRemove, got \(outcome)")
            return
        }
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test("a host filesystem item pointing at a critical system path is refused by the DeletionEngine")
    func filesystemItemRefusesCriticalPath() async {
        let deletionEngine = DeletionEngine(logger: InMemoryOperationLogger())
        let engine = DockerCleanupEngine(commandRunner: FakeDockerCommandRunner(), deletionEngine: deletionEngine, logger: InMemoryDockerOperationLogger())

        let outcome = await engine.remove(makeFileItem(path: "/System/Library"), mode: .real)

        guard case .failed = outcome else {
            Issue.record("expected failed, got \(outcome)")
            return
        }
    }

    @Test("a host filesystem item on a user-excluded path is refused (exclusions protect Docker host data too)")
    func filesystemItemRespectsUserExclusions() async throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }
        let file = scratch.appendingPathComponent("Docker.raw")
        try TestFixtures.writeFile(at: file, contents: "0123456789")

        let deletionEngine = DeletionEngine(
            exclusions: UserExclusionList(excludedPaths: [file.path]),
            logger: InMemoryOperationLogger(),
            trashMover: FakeTrashMover(trashDirectory: scratch.appendingPathComponent("trash"))
        )
        let engine = DockerCleanupEngine(commandRunner: FakeDockerCommandRunner(), deletionEngine: deletionEngine, logger: InMemoryDockerOperationLogger())

        let outcome = await engine.remove(makeFileItem(path: file.path), mode: .real)

        guard case .failed = outcome else {
            Issue.record("expected failed (excluded), got \(outcome)")
            return
        }
        #expect(FileManager.default.fileExists(atPath: file.path))
    }
}
