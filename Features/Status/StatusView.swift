import SwiftUI

struct StatusView: View {
    @State private var viewModel = StatusViewModel()

    private enum HeroMetric { case cpu, memory, disk }

    /// Whichever of CPU/Memory/Disk currently has the highest usage becomes
    /// the large tile — the layout itself points at what needs attention
    /// right now, instead of a fixed CPU-always-first arrangement.
    private var heroMetric: HeroMetric {
        let cpu = viewModel.snapshot.cpu.totalUsagePercent
        let memory = viewModel.snapshot.memory.usedPercent
        let disk = viewModel.snapshot.disk.usedPercent
        if disk >= cpu, disk >= memory { return .disk }
        if memory >= cpu { return .memory }
        return .cpu
    }

    var body: some View {
        Group {
            if viewModel.hasSampledOnce {
                ScrollView {
                    HStack(alignment: .top, spacing: 14) {
                        heroTile
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 14) {
                            if heroMetric != .cpu {
                                CPUGaugeView(cpu: viewModel.snapshot.cpu, style: .compact)
                            }
                            if heroMetric != .memory {
                                MemoryGaugeView(memory: viewModel.snapshot.memory, style: .compact)
                            }
                            if heroMetric != .disk {
                                DiskUsageView(disk: viewModel.snapshot.disk, style: .compact)
                            }
                            NetworkThroughputView(network: viewModel.snapshot.network)
                        }
                        .frame(width: 240)
                    }
                    .padding()
                }
            } else {
                ProgressView("正在采集系统数据…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("状态")
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    @ViewBuilder
    private var heroTile: some View {
        switch heroMetric {
        case .cpu: CPUGaugeView(cpu: viewModel.snapshot.cpu, style: .hero)
        case .memory: MemoryGaugeView(memory: viewModel.snapshot.memory, style: .hero)
        case .disk: DiskUsageView(disk: viewModel.snapshot.disk, style: .hero)
        }
    }
}

#Preview {
    StatusView()
}
