import Foundation
import IOKit.ps

enum BatteryMonitor {
    static func sample() -> BatterySnapshot {
        guard
            let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
            let source = sources.first,
            let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: AnyObject]
        else {
            return .unavailable
        }

        let currentCapacity = description[kIOPSCurrentCapacityKey as String] as? Int ?? 0
        let maxCapacity = description[kIOPSMaxCapacityKey as String] as? Int ?? 100
        let percentage = maxCapacity > 0 ? Int((Double(currentCapacity) / Double(maxCapacity) * 100).rounded()) : 0
        // `kIOPSPowerSourceStateKey` only says AC vs. battery power, not
        // whether the battery itself is actively topping up — a battery
        // that's already full while plugged in reads "AC Power" there but
        // is NOT charging. `kIOPSIsChargingKey` is the real signal,
        // confirmed against this machine's own `pmset -g batt` output
        // ("AC attached; not charging") diverging from the AC-power state.
        let isCharging = description[kIOPSIsChargingKey as String] as? Bool ?? false

        return BatterySnapshot(percentage: min(max(percentage, 0), 100), isCharging: isCharging, isPresent: true)
    }
}
