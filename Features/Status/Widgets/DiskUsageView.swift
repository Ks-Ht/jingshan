import JingshanCore
import SwiftUI

struct DiskUsageView: View {
    let disk: DiskSnapshot
    let history: [Double]

    private var tint: Color { SystemHealthTint.forUsagePercent(disk.usedPercent) }

    var body: some View {
        MetricSparklineCard(
            title: "磁盘",
            systemImage: "internaldrive",
            detailPrimary: "可用 \(ByteFormatter.string(fromBytes: disk.freeBytes))",
            detailSecondary: "共 \(ByteFormatter.string(fromBytes: disk.totalBytes))",
            percent: disk.usedPercent,
            history: history,
            tint: tint,
            needsAttention: tint != .green
        )
    }
}

#Preview {
    DiskUsageView(
        disk: DiskSnapshot(totalBytes: 500_000_000_000, freeBytes: 58_000_000_000),
        history: [70, 75, 80, 85, 88]
    )
    .padding()
}
