import Foundation
import Testing

@testable import JingshanCore

@Suite("SystemMetricsSampler")
struct SystemMetricsSamplerTests {
    @Test("reports plausible memory and disk figures against the real system")
    func reportsPlausibleStaticFigures() async {
        let sampler = SystemMetricsSampler()
        let snapshot = await sampler.sample()

        #expect(snapshot.memory.totalBytes > 0)
        #expect(snapshot.memory.totalBytes == ProcessInfo.processInfo.physicalMemory)
        // The active+wired+compressed accounting must never exceed physical
        // RAM — regression guard for the M16 memory-accuracy fix (the old
        // `total - free_count` formula could not overshoot by construction,
        // but a hand-summed replacement could if a field were misread).
        #expect(snapshot.memory.usedBytes <= snapshot.memory.totalBytes)
        #expect(snapshot.memory.usedPercent >= 0 && snapshot.memory.usedPercent <= 100)
        #expect(snapshot.disk.totalBytes > 0)
        #expect(snapshot.disk.usedPercent >= 0 && snapshot.disk.usedPercent <= 100)
    }

    @Test("CPU core count matches ProcessInfo, and a second sample yields a bounded usage percentage")
    func cpuUsageIsBoundedAfterASecondSample() async throws {
        let sampler = SystemMetricsSampler()
        let first = await sampler.sample()
        #expect(first.cpu.coreCount == ProcessInfo.processInfo.processorCount)

        try await Task.sleep(for: .milliseconds(200))
        let second = await sampler.sample()

        #expect(second.cpu.totalUsagePercent >= 0 && second.cpu.totalUsagePercent <= 100)
        #expect(second.cpu.perCoreUsagePercent.allSatisfy { $0 >= 0 && $0 <= 100 })
        #expect(second.cpu.perCoreUsagePercent.count == second.cpu.coreCount)
    }

    @Test("network throughput is non-negative on a second sample")
    func networkThroughputIsNonNegative() async throws {
        let sampler = SystemMetricsSampler()
        _ = await sampler.sample()
        try await Task.sleep(for: .milliseconds(200))
        let second = await sampler.sample()

        #expect(second.network.downloadBytesPerSecond >= 0)
        #expect(second.network.uploadBytesPerSecond >= 0)
    }

    @Test("battery reading is always present after a real sample, with a plausible percentage regardless of hardware")
    func batteryReadingIsPlausible() async throws {
        // Deliberately does not assert `isPresent` either way — this suite
        // runs on whatever Mac happens to build the project, desktop or
        // laptop, and a real reading should never crash or return an
        // out-of-range percentage on either kind. `snapshot.battery` itself
        // must be non-nil, though: `SystemMetricsSampler.sample()` always
        // populates it (only the unsampled `.empty` sentinel leaves it nil).
        let sampler = SystemMetricsSampler()
        let snapshot = await sampler.sample()

        let battery = try #require(snapshot.battery)
        #expect(battery.percentage >= 0)
        #expect(battery.percentage <= 100)
    }
}

@Suite("NetworkMonitor interface filtering")
struct NetworkMonitorInterfaceFilteringTests {
    @Test(
        "excludes known virtual/tunnel interface name prefixes",
        arguments: ["utun6", "utun0", "awdl0", "llw0", "bridge0", "anpi0", "anpi1", "ap1", "p2p0", "gif0", "stf0"]
    )
    func excludesVirtualInterfaces(name: String) {
        #expect(!NetworkMonitor.isPhysicalCandidate(interfaceName: name))
    }

    @Test(
        "keeps real physical-looking interfaces",
        arguments: ["en0", "en1", "en10"]
    )
    func keepsPhysicalInterfaces(name: String) {
        #expect(NetworkMonitor.isPhysicalCandidate(interfaceName: name))
    }
}
