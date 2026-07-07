import Foundation

public struct CPUSnapshot: Sendable, Equatable {
    public let totalUsagePercent: Double
    public let perCoreUsagePercent: [Double]
    public let coreCount: Int

    public init(totalUsagePercent: Double, perCoreUsagePercent: [Double], coreCount: Int) {
        self.totalUsagePercent = totalUsagePercent
        self.perCoreUsagePercent = perCoreUsagePercent
        self.coreCount = coreCount
    }

    public static let empty = CPUSnapshot(totalUsagePercent: 0, perCoreUsagePercent: [], coreCount: 0)
}

public struct MemorySnapshot: Sendable, Equatable {
    public let totalBytes: UInt64
    public let usedBytes: UInt64
    public let freeBytes: UInt64

    public init(totalBytes: UInt64, usedBytes: UInt64, freeBytes: UInt64) {
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.freeBytes = freeBytes
    }

    public var usedPercent: Double {
        totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) * 100 : 0
    }

    public static let empty = MemorySnapshot(totalBytes: 0, usedBytes: 0, freeBytes: 0)
}

public struct DiskSnapshot: Sendable, Equatable {
    public let totalBytes: Int64
    public let freeBytes: Int64

    public init(totalBytes: Int64, freeBytes: Int64) {
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
    }

    public var usedBytes: Int64 { max(totalBytes - freeBytes, 0) }
    public var usedPercent: Double {
        totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) * 100 : 0
    }

    public static let empty = DiskSnapshot(totalBytes: 0, freeBytes: 0)
}

public struct NetworkSnapshot: Sendable, Equatable {
    public let downloadBytesPerSecond: Double
    public let uploadBytesPerSecond: Double

    public init(downloadBytesPerSecond: Double, uploadBytesPerSecond: Double) {
        self.downloadBytesPerSecond = downloadBytesPerSecond
        self.uploadBytesPerSecond = uploadBytesPerSecond
    }

    public static let empty = NetworkSnapshot(downloadBytesPerSecond: 0, uploadBytesPerSecond: 0)
}

/// `isPresent` distinguishes "this Mac has no battery at all" (desktop
/// Macs) from `SystemSnapshot.battery == nil` ("we haven't sampled yet") —
/// two different kinds of absence that the UI needs to tell apart.
public struct BatterySnapshot: Sendable, Equatable {
    public let percentage: Int
    public let isCharging: Bool
    public let isPresent: Bool

    public init(percentage: Int, isCharging: Bool, isPresent: Bool) {
        self.percentage = percentage
        self.isCharging = isCharging
        self.isPresent = isPresent
    }

    public static let unavailable = BatterySnapshot(percentage: 0, isCharging: false, isPresent: false)
}

public struct SystemSnapshot: Sendable, Equatable {
    public let cpu: CPUSnapshot
    public let memory: MemorySnapshot
    public let disk: DiskSnapshot
    public let network: NetworkSnapshot
    public let battery: BatterySnapshot?
    public let timestamp: Date

    public init(
        cpu: CPUSnapshot,
        memory: MemorySnapshot,
        disk: DiskSnapshot,
        network: NetworkSnapshot,
        battery: BatterySnapshot? = nil,
        timestamp: Date
    ) {
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.network = network
        self.battery = battery
        self.timestamp = timestamp
    }

    public static let empty = SystemSnapshot(
        cpu: .empty,
        memory: .empty,
        disk: .empty,
        network: .empty,
        battery: nil,
        timestamp: .distantPast
    )
}
