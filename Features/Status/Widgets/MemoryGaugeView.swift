import JingshanCore
import SwiftUI

struct MemoryGaugeView: View {
    let memory: MemorySnapshot
    var style: MetricTileStyle = .compact

    private var tint: Color { SystemHealthTint.forUsagePercent(memory.usedPercent) }

    var body: some View {
        Group {
            switch style {
            case .hero:
                VStack(alignment: .leading, spacing: 14) {
                    if tint != .green {
                        Label("需要关注", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RiskTint.destructive)
                    }
                    HStack(spacing: 20) {
                        MetricRing(percent: memory.usedPercent, tint: tint, diameter: 108, lineWidth: 11)
                        infoBlock
                    }
                }
            case .compact:
                HStack(spacing: 12) {
                    MetricRing(percent: memory.usedPercent, tint: tint, diameter: 52, lineWidth: 7)
                    infoBlock
                }
            }
        }
        .metricTileBackground(style: style)
    }

    private var infoBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("内存")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text("已用 \(ByteFormatter.string(fromBytes: Int64(memory.usedBytes)))")
                .font(style == .hero ? .body.weight(.semibold) : .subheadline.weight(.semibold))
            Text("共 \(ByteFormatter.string(fromBytes: Int64(memory.totalBytes)))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    VStack {
        MemoryGaugeView(memory: MemorySnapshot(totalBytes: 32_000_000_000, usedBytes: 27_000_000_000, freeBytes: 5_000_000_000), style: .hero)
        MemoryGaugeView(memory: MemorySnapshot(totalBytes: 32_000_000_000, usedBytes: 18_000_000_000, freeBytes: 14_000_000_000), style: .compact)
    }
    .padding()
}
