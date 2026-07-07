import JingshanCore
import SwiftUI

struct MemoryGaugeView: View {
    let memory: MemorySnapshot
    let history: [Double]

    private var tint: Color { SystemHealthTint.forUsagePercent(memory.usedPercent) }

    var body: some View {
        MetricSparklineCard(
            title: "内存",
            systemImage: "memorychip",
            detailPrimary: "已用 \(ByteFormatter.string(fromBytes: Int64(memory.usedBytes)))",
            detailSecondary: "共 \(ByteFormatter.string(fromBytes: Int64(memory.totalBytes)))",
            percent: memory.usedPercent,
            history: history,
            tint: tint,
            needsAttention: tint != .green
        )
    }
}

#Preview {
    MemoryGaugeView(
        memory: MemorySnapshot(totalBytes: 32_000_000_000, usedBytes: 27_000_000_000, freeBytes: 5_000_000_000),
        history: [40, 55, 60, 70, 84]
    )
    .padding()
}
