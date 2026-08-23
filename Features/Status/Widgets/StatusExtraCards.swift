import JingshanCore
import SwiftUI

/// Static machine facts (A3): model / macOS / cores / memory / uptime / load.
struct SystemInfoCard: View {
    let info: SystemInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header("系统信息", systemImage: "cpu", tint: InkPalette.statusAccent)
            infoRow("机型", info.modelIdentifier)
            infoRow("系统", info.osVersionString.replacingOccurrences(of: "Version ", with: ""))
            infoRow("核心", "\(info.coreCount) 核")
            infoRow("内存", ByteFormatter.string(fromBytes: info.physicalMemoryBytes))
            infoRow("开机时长", uptimeText)
            if info.loadAverage.count == 3 {
                infoRow("负载", info.loadAverage.map { String(format: "%.2f", $0) }.joined(separator: " · "))
            }
        }
        .bentoCard()
        .accessibilityElement(children: .combine)
    }

    private var uptimeText: String {
        let total = Int(info.uptimeSeconds)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 { return "\(days) 天 \(hours) 小时" }
        if hours > 0 { return "\(hours) 小时 \(minutes) 分" }
        return "\(minutes) 分"
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption.weight(.medium)).lineLimit(1).truncationMode(.middle)
        }
    }
}

/// Per-core CPU usage (A3) — the data was already sampled; this surfaces it.
struct PerCoreCard: View {
    let perCore: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header("每核心占用", systemImage: "cpu.fill", tint: InkPalette.statusAccent)
            if perCore.isEmpty {
                Text("暂无数据").font(.caption).foregroundStyle(.secondary)
            } else {
                let columns = [GridItem(.adaptive(minimum: 70), spacing: 8)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(Array(perCore.enumerated()), id: \.offset) { index, value in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("#\(index + 1)").font(.caption2).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(value.rounded()))%").font(.caption2.weight(.medium)).monospacedDigit()
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.primary.opacity(0.08))
                                    Capsule().fill(tint(value)).frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(min(max(value, 0), 100) / 100))))
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                }
            }
        }
        .bentoCard()
    }

    private func tint(_ value: Double) -> Color {
        SystemHealthTint.forUsagePercent(value)
    }
}

/// Top processes by CPU (A3), refreshed live from `ps`.
struct TopProcessesCard: View {
    let rows: [ProcessUsageRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header("占用最高的进程", systemImage: "list.bullet.rectangle", tint: InkPalette.statusAccent)
            if rows.isEmpty {
                Text("正在采集…").font(.caption).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(rows) { row in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(SystemHealthTint.forUsagePercent(row.cpuPercent))
                                .frame(width: 5, height: 5)
                            Text(row.name)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text("\(String(format: "%.1f", row.cpuPercent))%")
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(SystemHealthTint.forUsagePercent(row.cpuPercent))
                        }
                    }
                }
            }
        }
        .bentoCard()
        .accessibilityElement(children: .combine)
    }
}

private func header(_ title: String, systemImage: String, tint: Color) -> some View {
    HStack(spacing: 6) {
        Image(systemName: systemImage).foregroundStyle(tint).accessibilityHidden(true)
        Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
    }
}
