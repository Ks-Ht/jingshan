import Foundation

public enum DockerCleanupMode: Sendable, Equatable {
    case dryRun
    case real
}

public enum DockerCleanupOutcome: Sendable, Equatable {
    case wouldRemove(DockerCleanableItem)
    case removed(DockerCleanableItem, freedBytes: Int64?)
    case failed(DockerCleanableItem, error: String)
}

public protocol DockerDiskSafetyChecking: Sendable {
    func isSafeToRemoveDiskImage() async -> Bool
}

/// Re-checks both Docker Desktop and the daemon at the Docker-specific
/// mutation choke point. A scan-time/UI-time result is not sufficient: the
/// app or daemon may start while the confirmation sheet is open.
public struct DefaultDockerDiskSafetyChecker: DockerDiskSafetyChecking {
    private let availability: DockerAvailability

    public init(commandRunner: DockerCommandRunning?) {
        self.availability = DockerAvailability(commandRunner: commandRunner)
    }

    public func isSafeToRemoveDiskImage() async -> Bool {
        let desktopRunning = await MainActor.run { DockerAvailability.isDockerDesktopRunning() }
        guard !desktopRunning else { return false }
        return await availability.checkStatus() != .available
    }
}

/// The single choke point for removing any Docker-related item. Nothing
/// else in the app invokes `docker rm`/`rmi`/`builder prune`/`volume rm`
/// or deletes Docker host files directly — every removal goes through here.
///
/// The two removal mechanisms stay strictly separate: `.dockerCommand`
/// items go to the docker CLI; `.filesystemPath` items go to the audited
/// `DeletionEngine` (path validation, protected-path checks, exclusion
/// list, Trash routing, logging). A host file is always Trash-routed in
/// real mode, so even a full "reset Docker" (deleting the VM disk) is
/// recoverable from the Trash.
public final class DockerCleanupEngine: @unchecked Sendable {
    private let commandRunner: DockerCommandRunning
    private let deletionEngine: DeletionEngineProtocol
    private let logger: DockerOperationLogging
    private let diskSafetyChecker: DockerDiskSafetyChecking

    public init(
        commandRunner: DockerCommandRunning,
        deletionEngine: DeletionEngineProtocol = DeletionEngine(),
        logger: DockerOperationLogging = DockerOperationLogger(),
        diskSafetyChecker: DockerDiskSafetyChecking? = nil
    ) {
        self.commandRunner = commandRunner
        self.deletionEngine = deletionEngine
        self.logger = logger
        self.diskSafetyChecker = diskSafetyChecker ?? DefaultDockerDiskSafetyChecker(commandRunner: commandRunner)
    }

    @discardableResult
    public func remove(_ item: DockerCleanableItem, mode: DockerCleanupMode) async -> DockerCleanupOutcome {
        switch item.removal {
        case .dockerCommand(let arguments):
            return await removeViaCommand(item, arguments: arguments, mode: mode)
        case .verifiedDockerCommand(let preflightArguments, let expectedOutput, let arguments):
            return await removeViaVerifiedCommand(
                item,
                preflightArguments: preflightArguments,
                expectedOutput: expectedOutput,
                arguments: arguments,
                mode: mode
            )
        case .filesystemPath(let path):
            return await removeViaFilesystem(item, path: path, mode: mode)
        }
    }

    private func removeViaVerifiedCommand(
        _ item: DockerCleanableItem,
        preflightArguments: [String],
        expectedOutput: String,
        arguments: [String],
        mode: DockerCleanupMode
    ) async -> DockerCleanupOutcome {
        if mode == .dryRun {
            record(item, outcome: "would_remove", detail: nil)
            return .wouldRemove(item)
        }
        do {
            let currentOutput = try await commandRunner.run(preflightArguments, timeout: 15)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let expected = expectedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard currentOutput == expected else {
                record(item, outcome: "failed", detail: "resource_identity_changed")
                return .failed(item, error: "资源在确认后已变化，请重新扫描并确认")
            }
            return await removeViaCommand(item, arguments: arguments, mode: mode)
        } catch {
            record(item, outcome: "failed", detail: "identity_check_failed: \(error)")
            return .failed(item, error: "无法确认资源仍是扫描时的对象，请重新扫描")
        }
    }

    private func removeViaCommand(_ item: DockerCleanableItem, arguments: [String], mode: DockerCleanupMode) async -> DockerCleanupOutcome {
        if mode == .dryRun {
            record(item, outcome: "would_remove", detail: nil)
            return .wouldRemove(item)
        }
        do {
            _ = try await commandRunner.run(arguments, timeout: timeout(for: item.kind))
            record(item, outcome: "removed", detail: nil)
            return .removed(item, freedBytes: item.sizeBytes)
        } catch {
            record(item, outcome: "failed", detail: "\(error)")
            return .failed(item, error: "\(error)")
        }
    }

    private func removeViaFilesystem(_ item: DockerCleanableItem, path: String, mode: DockerCleanupMode) async -> DockerCleanupOutcome {
        if item.kind == .diskImage, mode == .real,
           !(await diskSafetyChecker.isSafeToRemoveDiskImage())
        {
            record(item, outcome: "failed", detail: "docker_became_active")
            return .failed(item, error: "Docker 已启动或正在启动，虚拟磁盘未清理；请退出 Docker 后重新扫描")
        }
        let deletionMode: DeletionMode = (mode == .dryRun) ? .dryRun : .trash
        let outcome = deletionEngine.delete(
            path: path,
            mode: deletionMode,
            associatedBundleIdentifier: nil,
            allowProtectedAppOverride: false,
            precomputedSizeBytes: item.sizeBytes
        )
        switch outcome {
        case .wouldDelete:
            record(item, outcome: "would_remove", detail: nil)
            return .wouldRemove(item)
        case .movedToTrash(_, _, let size), .permanentlyDeleted(_, let size):
            record(item, outcome: "removed", detail: nil)
            return .removed(item, freedBytes: size ?? item.sizeBytes)
        case .alreadyAbsent:
            record(item, outcome: "removed", detail: "already_absent")
            return .removed(item, freedBytes: 0)
        case .skippedExcluded(let validated):
            record(item, outcome: "failed", detail: "skipped_excluded: \(validated.originalPath)")
            return .failed(item, error: "已被排除名单保护，未删除")
        case .skippedProtectedApp(_, let bundleID, let reason):
            record(item, outcome: "failed", detail: "skipped_protected: \(bundleID) \(reason)")
            return .failed(item, error: reason)
        case .failed(_, let error):
            record(item, outcome: "failed", detail: "\(error)")
            return .failed(item, error: "\(error)")
        }
    }

    private func timeout(for kind: DockerResourceKind) -> TimeInterval {
        // Build cache prune can take a while when there's a lot to walk;
        // everything else is normally near-instant.
        kind == .buildCache ? 180 : 30
    }

    private func record(_ item: DockerCleanableItem, outcome: String, detail: String?) {
        logger.log(
            DockerOperationLogEntry(
                timestamp: Date(),
                kind: item.kind.rawValue,
                resourceID: item.id,
                displayName: item.displayName,
                arguments: item.removal.auditDescription,
                outcome: outcome,
                detail: detail
            )
        )
    }
}
