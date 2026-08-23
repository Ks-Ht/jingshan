import JingshanCore
import SwiftUI

/// No sparkline here on purpose — battery percentage barely moves within a
/// 60-second window, so a trend line would just read as a flat, uninformative
/// stripe. A simple current-state card (percentage + charging status) is
/// more honest about what's actually worth showing at this timescale.
struct BatteryCard: View {
    let battery: BatterySnapshot

    private var tint: Color {
        if battery.isCharging { return InkPalette.accent }
        switch battery.percentage {
        case ..<20: return RiskTint.destructive
        case ..<40: return InkPalette.amber
        default: return InkPalette.accent
        }
    }

    private var systemImage: String {
        if battery.isCharging { return "bolt.batteryblock.fill" }
        switch battery.percentage {
        case ..<20: return "battery.25"
        case ..<60: return "battery.50"
        case ..<90: return "battery.75"
        default: return "battery.100"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Text("电池")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if battery.isCharging {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                        Text("充电中")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(InkPalette.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(InkPalette.accent.opacity(0.12), in: Capsule())
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(battery.percentage)%")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(battery.isCharging ? "电源适配器供电" : "正在使用电池")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Visual battery progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(battery.percentage) / 100)))
                }
            }
            .frame(height: 7)
        }
        .bentoCard()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    BatteryCard(battery: BatterySnapshot(percentage: 82, isCharging: true, isPresent: true))
        .padding()
}
