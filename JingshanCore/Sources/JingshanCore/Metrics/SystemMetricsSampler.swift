import Foundation

/// Samples CPU, memory, disk, and network in one call. An `actor` because
/// `CPUMonitor`/`NetworkMonitor` carry mutable delta-tracking state between
/// samples, and this may be driven by a UI timer loop on a different task.
public actor SystemMetricsSampler {
    private var cpuMonitor = CPUMonitor()
    private var networkMonitor = NetworkMonitor()

    public init() {}

    public func sample() -> SystemSnapshot {
        SystemSnapshot(
            cpu: cpuMonitor.sample(),
            memory: MemoryMonitor.sample(),
            disk: DiskMonitor.sample(),
            network: networkMonitor.sample(),
            timestamp: Date()
        )
    }
}
