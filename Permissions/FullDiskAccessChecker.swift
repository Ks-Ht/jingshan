import Foundation

/// There is no public API to directly query Full Disk Access grant state,
/// so this probes the one file that reliably requires FDA to read on every
/// Mac: the TCC database itself. A non-sandboxed app can read it once (and
/// only once) the user has granted Full Disk Access in System Settings.
enum FullDiskAccessChecker {
    static func hasFullDiskAccess(fileManager: FileManager = .default) -> Bool {
        let tccDatabasePath = NSHomeDirectory() + "/Library/Application Support/com.apple.TCC/TCC.db"
        return fileManager.isReadableFile(atPath: tccDatabasePath)
    }
}
