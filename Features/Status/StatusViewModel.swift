import Foundation
import JingshanCore

@MainActor
@Observable
final class StatusViewModel {
    private(set) var snapshot: SystemSnapshot = .empty

    /// Rolling ~60-second history for the Bento sparklines — presentation-
    /// only state, deliberately kept here rather than in JingshanCore
    /// (which holds only point-in-time sampling with no historical
    /// concept), consistent with how `hasSampledOnce` was handled before.
    private(set) var cpuHistory: [Double] = []
    private(set) var memoryHistory: [Double] = []
    private(set) var diskHistory: [Double] = []
    private(set) var networkDownHistory: [Double] = []
    private(set) var networkUpHistory: [Double] = []
    private let maxHistory = 60

    /// Extra monitoring (A3): static system facts + a live top-processes table.
    private(set) var systemInfo = SystemInfo.current()
    private(set) var topProcesses: [ProcessUsageRow] = []

    private let sampler = SystemMetricsSampler()
    private var samplingTask: Task<Void, Never>?

    /// `.empty`'s sentinel `.distantPast` timestamp means "no real sample
    /// yet" — used so the UI can show a loading state instead of a
    /// misleading "0 B" for the fraction of a second before the first
    /// sample arrives.
    var hasSampledOnce: Bool { snapshot.timestamp != .distantPast }

    /// A single at-a-glance number: 100 minus whichever of CPU/memory/disk
    /// is currently under the most pressure. Deliberately the same "worst
    /// resource" framing as `SystemHealthTint.forUsagePercent`, not a
    /// separately-tuned formula — the health-score ring and the individual
    /// CPU/Memory/Disk tiles must never visually disagree about whether
    /// things are fine. Known, accepted simplification: a machine at
    /// 90/20/10 scores the same as one at 90/90/90, since only the worst
    /// single figure drives the score — acceptable for an at-a-glance
    /// number, revisit only if that ever reads as wrong in practice.
    var healthScorePercent: Double {
        100 - worstUsagePercent
    }

    var worstUsagePercent: Double {
        max(snapshot.cpu.totalUsagePercent, snapshot.memory.usedPercent, snapshot.disk.usedPercent)
    }

    func start() {
        guard samplingTask == nil else { return }
        samplingTask = Task {
            var tick = 0
            while !Task.isCancelled {
                snapshot = await sampler.sample()
                appendHistory()
                systemInfo = SystemInfo.current()
                // Refresh the process table every other tick — `ps` is a
                // subprocess, no need to run it a full 60×/minute.
                if tick % 2 == 0 {
                    topProcesses = await ProcessLister.topProcesses(sortedBy: .cpu, limit: 6)
                }
                tick += 1
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stop() {
        samplingTask?.cancel()
        samplingTask = nil
    }

    private func appendHistory() {
        cpuHistory = capped(cpuHistory + [snapshot.cpu.totalUsagePercent])
        memoryHistory = capped(memoryHistory + [snapshot.memory.usedPercent])
        diskHistory = capped(diskHistory + [snapshot.disk.usedPercent])
        networkDownHistory = capped(networkDownHistory + [snapshot.network.downloadBytesPerSecond])
        networkUpHistory = capped(networkUpHistory + [snapshot.network.uploadBytesPerSecond])
    }

    private func capped(_ values: [Double]) -> [Double] {
        values.count > maxHistory ? Array(values.suffix(maxHistory)) : values
    }
}
