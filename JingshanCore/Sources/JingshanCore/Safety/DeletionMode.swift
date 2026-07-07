import Foundation

/// How `DeletionEngine.delete` should act once a path has passed validation.
public enum DeletionMode: Equatable, Sendable {
    /// Validate and log "would delete", no filesystem mutation at all.
    case dryRun
    /// Move to the user's Trash via `FileManager.trashItem` — the default,
    /// recoverable mode for every user-facing delete.
    case trash
    /// Permanently remove the item. `confirmed` is an engine-level gate, not
    /// just a UI-level one: the engine refuses outright when `false`, so no
    /// caller can permanently delete by forgetting a UI confirmation step.
    case permanent(confirmed: Bool)
}
