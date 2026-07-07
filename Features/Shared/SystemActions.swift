import AppKit
import Foundation

/// Small shared system affordances used across modules.
enum SystemActions {
    /// Opens the user's Trash in Finder. Offered after a cleanup so the user
    /// can immediately review — and restore — whatever was just moved there,
    /// reinforcing that the default delete is reversible.
    static func openTrash() {
        let trash = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".Trash")
        NSWorkspace.shared.open(trash)
    }
}
