import JingshanCore
import SwiftUI

struct CPUGaugeView: View {
    let cpu: CPUSnapshot
    var style: MetricTileStyle = .compact

    private var tint: Color { SystemHealthTint.forUsagePercent(cpu.totalUsagePercent) }

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
                        MetricRing(percent: cpu.totalUsagePercent, tint: tint, diameter: 108, lineWidth: 11)
                        infoBlock
                    }
                }
            case .compact:
                HStack(spacing: 12) {
                    MetricRing(percent: cpu.totalUsagePercent, tint: tint, diameter: 52, lineWidth: 7)
                    infoBlock
                }
            }
        }
        .metricTileBackground(style: style)
    }

    private var infoBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("CPU")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text("总体使用率")
                .font(style == .hero ? .body.weight(.semibold) : .subheadline.weight(.semibold))
            if cpu.coreCount > 0 {
                Text("\(cpu.coreCount) 核心")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    VStack {
        CPUGaugeView(cpu: CPUSnapshot(totalUsagePercent: 88, perCoreUsagePercent: [30, 55, 20, 60], coreCount: 4), style: .hero)
        CPUGaugeView(cpu: CPUSnapshot(totalUsagePercent: 42, perCoreUsagePercent: [30, 55, 20, 60], coreCount: 4), style: .compact)
    }
    .padding()
}
