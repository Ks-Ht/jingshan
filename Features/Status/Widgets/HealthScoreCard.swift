import SwiftUI

/// The Bento grid's one card that keeps the big `RingGauge` treatment for
/// its own sake (every other card pairs a compact ring with a sparkline) —
/// this is the single "how's the whole machine doing" number the spec asks
/// for, so it gets to be the visual anchor of the page.
struct HealthScoreCard: View {
    let healthScorePercent: Double
    let worstUsagePercent: Double
    let machineInfo: String

    private var tint: Color { SystemHealthTint.forUsagePercent(worstUsagePercent) }

    private var statusText: String {
        if healthScorePercent >= 80 { return "运行良好" }
        if healthScorePercent >= 60 { return "状态尚可" }
        return "建议优化"
    }

    var body: some View {
        // Machine spec sits on its own full-width line below the ring+title row
        // so a long "10 核 · 17.18 GB · 245 GB" has the whole card to lay out on
        // and never wraps mid-value (it was cramped beside the ring before).
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                RingGauge(
                    progress: healthScorePercent / 100,
                    valueText: "\(Int(healthScorePercent.rounded()))",
                    captionText: "健康分",
                    tint: tint,
                    diameter: 88,
                    lineWidth: 9
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text("系统健康度").font(.headline)
                    Text(statusText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(tint)
                }
                Spacer(minLength: 0)
            }
            Text(machineInfo)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .bentoCard()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HealthScoreCard(healthScorePercent: 62, worstUsagePercent: 38, machineInfo: "8 核心 · 16 GB 内存 · 494 GB 磁盘")
        .padding()
}
