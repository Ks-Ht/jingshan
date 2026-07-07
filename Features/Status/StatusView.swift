import JingshanCore
import SwiftUI

struct StatusView: View {
    let viewModel: StatusViewModel

    private let columns = [GridItem(.adaptive(minimum: 240), spacing: 14)]

    var body: some View {
        Group {
            if viewModel.hasSampledOnce {
                ScrollView {
                    VStack(spacing: 16) {
                        HeroHeader(motif: .status, title: "状态", tint: InkPalette.statusAccent) {
                            EmptyView()
                        }

                        LazyVGrid(columns: columns, spacing: 14) {
                            HealthScoreCard(
                                healthScorePercent: viewModel.healthScorePercent,
                                worstUsagePercent: viewModel.worstUsagePercent,
                                machineInfo: machineInfoText
                            )
                            CPUGaugeView(cpu: viewModel.snapshot.cpu, history: viewModel.cpuHistory)
                            MemoryGaugeView(memory: viewModel.snapshot.memory, history: viewModel.memoryHistory)
                            DiskUsageView(disk: viewModel.snapshot.disk, history: viewModel.diskHistory)
                            NetworkThroughputView(
                                network: viewModel.snapshot.network,
                                downloadHistory: viewModel.networkDownHistory,
                                uploadHistory: viewModel.networkUpHistory
                            )
                            if let battery = viewModel.snapshot.battery, battery.isPresent {
                                BatteryCard(battery: battery)
                            }
                            PerCoreCard(perCore: viewModel.snapshot.cpu.perCoreUsagePercent)
                            SystemInfoCard(info: viewModel.systemInfo)
                            TopProcessesCard(rows: viewModel.topProcesses)
                        }
                    }
                    .padding()
                }
            } else {
                ScanningStateView(statusText: "正在采集系统数据…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("状态")
        .tint(InkPalette.statusAccent)
        // Sampling start/stop is driven by RootView's active-tab change, not
        // by this view's appear/disappear — Home and Status share one
        // `statusVM` and toggling from both races during a tab cross-fade.
    }

    // Compact machine spec ("10 核 · 17.18 GB · 245 GB") — the trailing
    // "核心 / 内存 / 磁盘" labels were dropped so the line fits on one row
    // without wrapping (see HealthScoreCard for the layout that gives it the
    // full card width).
    private var machineInfoText: String {
        let cpu = viewModel.snapshot.cpu
        let memory = viewModel.snapshot.memory
        let disk = viewModel.snapshot.disk
        var parts: [String] = []
        if cpu.coreCount > 0 { parts.append("\(cpu.coreCount) 核") }
        if memory.totalBytes > 0 { parts.append(ByteFormatter.string(fromBytes: Int64(memory.totalBytes))) }
        if disk.totalBytes > 0 { parts.append(ByteFormatter.string(fromBytes: disk.totalBytes)) }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    StatusView(viewModel: StatusViewModel())
}
