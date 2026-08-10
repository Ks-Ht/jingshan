import SwiftUI

/// The Bento-grid card shell shared by CPU/Memory/Disk: a compact `RingGauge`
/// for "the current value at a glance" beside a label + detail line +
/// ~60-second `Sparkline` for "which way has it been trending." Replaces the
/// old hero/compact dual-style `MetricTileStyle` system — every card in the
/// grid is the same size now, so there's no separate "big" variant to
/// maintain.
struct MetricSparklineCard: View {
    let title: String
    let systemImage: String
    let detailPrimary: String
    let detailSecondary: String?
    let percent: Double
    let history: [Double]
    let tint: Color
    var needsAttention: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true) // decorative; the title text says the same thing
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if needsAttention {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(SystemHealthTint.forUsagePercent(percent))
                        .accessibilityLabel("需要关注") // the only icon here carrying state not otherwise in text
                }
            }

            HStack(spacing: 14) {
                RingGauge(progress: percent / 100, valueText: "\(Int(percent.rounded()))%", tint: tint, diameter: 62, lineWidth: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(detailPrimary)
                        .font(.subheadline.weight(.semibold))
                        .contentTransition(.numericText())
                    if let detailSecondary {
                        Text(detailSecondary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Sparkline(values: history, tint: tint)
                .frame(height: 28)
                .accessibilityHidden(true) // decorative trend; the current value is already read via the ring + detail text
        }
        .bentoCard()
        .accessibilityElement(children: .combine)
    }
}
