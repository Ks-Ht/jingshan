import Foundation

enum DiskMonitor {
    static func sample(volumeURL: URL = URL(fileURLWithPath: "/")) -> DiskSnapshot {
        guard
            let values = try? volumeURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]),
            let total = values.volumeTotalCapacity
        else {
            return .empty
        }
        let available = values.volumeAvailableCapacityForImportantUsage ?? 0
        return DiskSnapshot(totalBytes: Int64(total), freeBytes: available)
    }
}
