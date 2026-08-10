import Foundation

/// Static, cheap-to-read system facts for the Status page's "系统信息" card.
/// Everything here uses public, documented APIs (sysctl / ProcessInfo /
/// getloadavg) — no private SMC/IOAccelerator keys — so nothing here degrades
/// or misreports across machines.
public struct SystemInfo: Sendable, Equatable {
    public let modelIdentifier: String
    public let osVersionString: String
    public let coreCount: Int
    public let physicalMemoryBytes: Int64
    public let uptimeSeconds: Double
    /// 1 / 5 / 15-minute load averages (empty if unavailable).
    public let loadAverage: [Double]

    public init(modelIdentifier: String, osVersionString: String, coreCount: Int, physicalMemoryBytes: Int64, uptimeSeconds: Double, loadAverage: [Double]) {
        self.modelIdentifier = modelIdentifier
        self.osVersionString = osVersionString
        self.coreCount = coreCount
        self.physicalMemoryBytes = physicalMemoryBytes
        self.uptimeSeconds = uptimeSeconds
        self.loadAverage = loadAverage
    }

    public static func current() -> SystemInfo {
        SystemInfo(
            modelIdentifier: sysctlString("hw.model") ?? "Mac",
            osVersionString: ProcessInfo.processInfo.operatingSystemVersionString,
            coreCount: ProcessInfo.processInfo.processorCount,
            physicalMemoryBytes: Int64(ProcessInfo.processInfo.physicalMemory),
            uptimeSeconds: ProcessInfo.processInfo.systemUptime,
            loadAverage: currentLoadAverage()
        )
    }

    static func currentLoadAverage() -> [Double] {
        var loads = [Double](repeating: 0, count: 3)
        let count = getloadavg(&loads, 3)
        return count == 3 ? loads : []
    }

    static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}
