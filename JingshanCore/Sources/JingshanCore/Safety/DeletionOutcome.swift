import Foundation

/// Every possible result of a `DeletionEngine.delete` call. Every case is
/// logged by the engine before it returns, so the operation log always has
/// an entry matching whatever the caller observed.
public enum DeletionOutcome: Equatable, Sendable {
    case wouldDelete(ValidatedPath, sizeBytes: Int64?)
    case movedToTrash(ValidatedPath, resultingURL: URL?, sizeBytes: Int64?)
    case permanentlyDeleted(ValidatedPath, sizeBytes: Int64?)
    /// The path did not exist at all (already gone). Treated as a benign
    /// no-op, not a failure, matching Mole's own `safe_remove` semantics.
    case alreadyAbsent(originalPath: String)
    case skippedExcluded(ValidatedPath)
    case skippedProtectedApp(ValidatedPath, bundleIdentifier: String, reason: String)
    case failed(originalPath: String, error: DeletionError)
}
