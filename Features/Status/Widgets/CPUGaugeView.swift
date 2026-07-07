import JingshanCore
import SwiftUI

struct CPUGaugeView: View {
    let cpu: CPUSnapshot
    let history: [Double]

    private var tint: Color { SystemHealthTint.forUsagePercent(cpu.totalUsagePercent) }

    var body: some View {
        MetricSparklineCard(
            title: "CPU",
            systemImage: "cpu",
            detailPrimary: "总体使用率",
            detailSecondary: cpu.coreCount > 0 ? "\(cpu.coreCount) 核心" : nil,
            percent: cpu.totalUsagePercent,
            history: history,
            tint: tint,
            needsAttention: tint != .green
        )
    }
}

#Preview {
    CPUGaugeView(cpu: CPUSnapshot(totalUsagePercent: 88, perCoreUsagePercent: [30, 55, 20, 60], coreCount: 4), history: [40, 55, 60, 70, 88])
        .padding()
}
