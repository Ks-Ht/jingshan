import Foundation

/// Abstracts the actual move-to-Trash call so tests can redirect it to a
/// throwaway directory instead of the real `~/.Trash` (mirrors Mole's
/// `MOLE_TEST_TRASH_DIR` test seam).
public protocol TrashMoving: Sendable {
    func moveToTrash(_ url: URL) throws -> URL?
}

public struct FileManagerTrashMover: TrashMoving {
    public init() {}

    public func moveToTrash(_ url: URL) throws -> URL? {
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
        return resultingURL as URL?
    }
}
