import Darwin
import Foundation

/// CPU usage is inherently a delta between two tick-count samples, so this
/// holds the previous sample internally. Owned by `SystemMetricsSampler`,
/// which is the only thing that calls `sample()` repeatedly.
struct CPUMonitor {
    private struct ProcessorTicks {
        let user: UInt32
        let system: UInt32
        let idle: UInt32
        let nice: UInt32
    }

    private var previousTicks: [ProcessorTicks]?

    mutating func sample() -> CPUSnapshot {
        guard let currentTicks = Self.currentProcessorTicks() else {
            return .empty
        }
        defer { previousTicks = currentTicks }

        guard let previous = previousTicks, previous.count == currentTicks.count else {
            // First sample: no delta available yet.
            return CPUSnapshot(totalUsagePercent: 0, perCoreUsagePercent: Array(repeating: 0, count: currentTicks.count), coreCount: currentTicks.count)
        }

        var perCoreUsage: [Double] = []
        perCoreUsage.reserveCapacity(currentTicks.count)
        var totalActiveDelta: UInt64 = 0
        var totalDelta: UInt64 = 0

        for (prev, current) in zip(previous, currentTicks) {
            let userDelta = UInt64(current.user &- prev.user)
            let systemDelta = UInt64(current.system &- prev.system)
            let idleDelta = UInt64(current.idle &- prev.idle)
            let niceDelta = UInt64(current.nice &- prev.nice)
            let activeDelta = userDelta + systemDelta + niceDelta
            let coreTotalDelta = activeDelta + idleDelta

            perCoreUsage.append(coreTotalDelta > 0 ? Double(activeDelta) / Double(coreTotalDelta) * 100 : 0)
            totalActiveDelta += activeDelta
            totalDelta += coreTotalDelta
        }

        let totalUsage = totalDelta > 0 ? Double(totalActiveDelta) / Double(totalDelta) * 100 : 0
        return CPUSnapshot(totalUsagePercent: totalUsage, perCoreUsagePercent: perCoreUsage, coreCount: currentTicks.count)
    }

    private static func currentProcessorTicks() -> [ProcessorTicks]? {
        var cpuCount: natural_t = 0
        var infoArrayPointer: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &infoArrayPointer, &infoCount)
        guard result == KERN_SUCCESS, let infoArrayPointer else { return nil }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: infoArrayPointer),
                vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            )
        }

        return infoArrayPointer.withMemoryRebound(to: processor_cpu_load_info.self, capacity: Int(cpuCount)) { loadInfo in
            (0..<Int(cpuCount)).map { index in
                let ticks = loadInfo[index].cpu_ticks
                return ProcessorTicks(user: ticks.0, system: ticks.1, idle: ticks.2, nice: ticks.3)
            }
        }
    }
}
