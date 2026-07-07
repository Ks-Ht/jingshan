import Foundation

/// The whole Trash as a single reviewable item — "empty Trash" is one
/// atomic action, not a per-file selection, matching how Finder and Mole
/// both treat it.
public struct TrashScanner: CategoryScanning {
    public let categoryID = "trash"
    public let displayName = "废纸篓"

    private let trashPath: String

    public init(trashPath: String = NSHomeDirectory() + "/.Trash") {
        self.trashPath = trashPath
    }

    public func scan() async -> ScanCategory {
        let item = await ScanningSupport.scanWholeDirectory(
            at: trashPath,
            displayLabel: "废纸篓"
        )
        return ScanCategory(id: categoryID, displayName: displayName, items: item.map { [$0] } ?? [])
    }
}
