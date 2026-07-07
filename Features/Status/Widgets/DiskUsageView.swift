import JingshanCore
import SwiftUI

struct DiskUsageView: View {
    let disk: DiskSnapshot
    var style: MetricTileStyle = .compact

    private var tint: Color { SystemHealthTint.forUsagePercent(disk.usedPercent) }

    var body: some View {
        Group {
            switch style {
            case .hero:
                VStack(alignment: .leading, spacing: 14) {
                    if tint != .green {
                        Label("空间紧张 · 优先关注", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RiskTint.destructive)
                    }
                    HStack(spacing: 20) {
                        MetricRing(percent: disk.usedPercent, tint: tint, diameter: 108, lineWidth: 11)
                        infoBlock
                    }
                }
            case .compact:
                HStack(spacing: 12) {
                    MetricRing(percent: disk.usedPercent, tint: tint, diameter: 52, lineWidth: 7)
                    infoBlock
                }
            }
        }
        .metricTileBackground(style: style)
    }

    private var infoBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("磁盘")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text("可用 \(ByteFormatter.string(fromBytes: disk.freeBytes))")
                .font(style == .hero ? .body.weight(.semibold) : .subheadline.weight(.semibold))
            Text("共 \(ByteFormatter.string(fromBytes: disk.totalBytes))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    VStack {
        DiskUsageView(disk: DiskSnapshot(totalBytes: 500_000_000_000, freeBytes: 58_000_000_000), style: .hero)
        DiskUsageView(disk: DiskSnapshot(totalBytes: 500_000_000_000, freeBytes: 120_000_000_000), style: .compact)
    }
    .padding()
}
