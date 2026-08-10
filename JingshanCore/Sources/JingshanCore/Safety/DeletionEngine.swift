import Foundation

public protocol DeletionEngineProtocol: Sendable {
    func delete(
        path: String,
        mode: DeletionMode,
        associatedBundleIdentifier: String?,
        allowProtectedAppOverride: Bool,
        precomputedSizeBytes: Int64?
    ) -> DeletionOutcome
}

/// The single choke point for deleting anything in Jingshan. Nothing else
/// in the codebase is allowed to call `FileManager.removeItem`/`trashItem`
/// directly — every delete must go through here so validation, exclusions,
/// app protection, dry-run, and audit logging stay consistent no matter
/// which feature triggered the delete. Mirrors Mole's `mole_delete`.
public final class DeletionEngine: DeletionEngineProtocol, @unchecked Sendable {
    private let validator: PathValidating
    private let protectionEvaluator: ProtectionEvaluator
    private let exclusions: UserExclusionList
    private let logger: OperationLogging
    private let fileManager: FileManager
    private let trashMover: TrashMoving

    public init(
        validator: PathValidating = PathValidator(),
        protectedApps: ProtectedAppAllowlist = .default,
        exclusions: UserExclusionList = UserExclusionList(),
        runningChecker: RunningApplicationChecking = WorkspaceRunningApplicationChecker(),
        logger: OperationLogging = OperationLogger(),
        fileManager: FileManager = .default,
        trashMover: TrashMoving = FileManagerTrashMover()
    ) {
        self.validator = validator
        self.protectionEvaluator = ProtectionEvaluator(protectedApps: protectedApps, runningChecker: runningChecker)
        self.exclusions = exclusions
        self.logger = logger
        self.fileManager = fileManager
        self.trashMover = trashMover
    }

    @discardableResult
    public func delete(
        path: String,
        mode: DeletionMode,
        associatedBundleIdentifier: String? = nil,
        allowProtectedAppOverride: Bool = false,
        precomputedSizeBytes: Int64? = nil
    ) -> DeletionOutcome {
        switch validator.validate(path) {
        case .failure(.pathDoesNotExist):
            record(action: "delete", originalPath: path, resolvedPath: path, sizeBytes: nil, outcome: "already_absent", detail: nil)
            return .alreadyAbsent(originalPath: path)

        case .failure(let error):
            record(action: "delete", originalPath: path, resolvedPath: path, sizeBytes: nil, outcome: "validation_failed", detail: "\(error)")
            return .failed(originalPath: path, error: .validationFailed(error))

        case .success(let validated):
            return performDelete(
                validated,
                mode: mode,
                associatedBundleIdentifier: associatedBundleIdentifier,
                allowProtectedAppOverride: allowProtectedAppOverride,
                precomputedSizeBytes: precomputedSizeBytes
            )
        }
    }

    private func performDelete(
        _ validated: ValidatedPath,
        mode: DeletionMode,
        associatedBundleIdentifier: String?,
        allowProtectedAppOverride: Bool,
        precomputedSizeBytes: Int64?
    ) -> DeletionOutcome {
        // Check the exclusion list against BOTH the original path and the
        // symlink-resolved path. The user's excluded entry may have been
        // stored unresolved (as picked in Settings) while the scanned item
        // is a symlink whose resolved path differs — matching only one side
        // would let a symlinked exclusion slip past this backstop.
        if exclusions.contains(resolvedPath: validated.originalPath)
            || exclusions.contains(resolvedPath: validated.resolvedPath)
        {
            record(
                action: "delete",
                originalPath: validated.originalPath,
                resolvedPath: validated.resolvedPath,
                sizeBytes: nil,
                outcome: "skipped_excluded",
                detail: nil
            )
            return .skippedExcluded(validated)
        }

        if let bundleID = associatedBundleIdentifier {
            if exclusions.containsBundleIdentifier(bundleID) {
                record(
                    action: "delete",
                    originalPath: validated.originalPath,
                    resolvedPath: validated.resolvedPath,
                    sizeBytes: nil,
                    outcome: "skipped_excluded",
                    detail: "bundle identifier excluded: \(bundleID)"
                )
                return .skippedExcluded(validated)
            }

            switch protectionEvaluator.evaluate(bundleIdentifier: bundleID, path: validated.originalPath) {
            case .notProtected:
                break
            case .staticallyProtected(let reason):
                return skipProtected(validated, bundleID: bundleID, reason: reason)
            case .runningApp(let reason):
                if !allowProtectedAppOverride {
                    return skipProtected(validated, bundleID: bundleID, reason: reason)
                }
            }
        }

        // The actual filesystem mutation always targets the original
        // (normalized) path, never the resolved one. Resolution exists so
        // validation can see through symlinks to their real destination —
        // but the object being deleted is whatever sits at the original
        // path. For a symlink, that's the link entry itself: deleting it
        // must remove the link, not reach through it and delete (or, if
        // broken, fail to find) whatever it points to.
        let mutationPath = PathValidator.normalize(validated.originalPath)
        let sizeBytes = precomputedSizeBytes ?? FileSizeCalculator.size(ofPath: mutationPath, fileManager: fileManager)

        switch mode {
        case .dryRun:
            record(
                action: "delete.dry_run",
                originalPath: validated.originalPath,
                resolvedPath: validated.resolvedPath,
                sizeBytes: sizeBytes,
                outcome: "would_delete",
                detail: nil
            )
            return .wouldDelete(validated, sizeBytes: sizeBytes)

        case .trash:
            do {
                let resultingURL = try trashMover.moveToTrash(URL(fileURLWithPath: mutationPath))
                record(
                    action: "delete.trash",
                    originalPath: validated.originalPath,
                    resolvedPath: validated.resolvedPath,
                    sizeBytes: sizeBytes,
                    outcome: "moved_to_trash",
                    detail: nil
                )
                return .movedToTrash(validated, resultingURL: resultingURL, sizeBytes: sizeBytes)
            } catch {
                record(
                    action: "delete.trash",
                    originalPath: validated.originalPath,
                    resolvedPath: validated.resolvedPath,
                    sizeBytes: sizeBytes,
                    outcome: "failed",
                    detail: "\(error)"
                )
                return .failed(originalPath: validated.originalPath, error: .filesystemError(description: "\(error)"))
            }

        case .permanent(let confirmed):
            guard confirmed else {
                record(
                    action: "delete.permanent",
                    originalPath: validated.originalPath,
                    resolvedPath: validated.resolvedPath,
                    sizeBytes: sizeBytes,
                    outcome: "refused_unconfirmed",
                    detail: nil
                )
                return .failed(originalPath: validated.originalPath, error: .permanentDeleteNotConfirmed)
            }
            do {
                try fileManager.removeItem(atPath: mutationPath)
                record(
                    action: "delete.permanent",
                    originalPath: validated.originalPath,
                    resolvedPath: validated.resolvedPath,
                    sizeBytes: sizeBytes,
                    outcome: "permanently_deleted",
                    detail: nil
                )
                return .permanentlyDeleted(validated, sizeBytes: sizeBytes)
            } catch {
                record(
                    action: "delete.permanent",
                    originalPath: validated.originalPath,
                    resolvedPath: validated.resolvedPath,
                    sizeBytes: sizeBytes,
                    outcome: "failed",
                    detail: "\(error)"
                )
                return .failed(originalPath: validated.originalPath, error: .filesystemError(description: "\(error)"))
            }
        }
    }

    private func skipProtected(_ validated: ValidatedPath, bundleID: String, reason: String) -> DeletionOutcome {
        record(
            action: "delete",
            originalPath: validated.originalPath,
            resolvedPath: validated.resolvedPath,
            sizeBytes: nil,
            outcome: "skipped_protected_app",
            detail: "\(bundleID): \(reason)"
        )
        return .skippedProtectedApp(validated, bundleIdentifier: bundleID, reason: reason)
    }

    private func record(action: String, originalPath: String, resolvedPath: String, sizeBytes: Int64?, outcome: String, detail: String?) {
        logger.log(
            OperationLogEntry(
                timestamp: Date(),
                action: action,
                originalPath: originalPath,
                resolvedPath: resolvedPath,
                sizeBytes: sizeBytes,
                outcome: outcome,
                detail: detail
            )
        )
    }
}
