import JingshanCore
import SwiftUI

/// No sparkline here on purpose — battery percentage barely moves within a
/// 60-second window, so a trend line would just read as a flat, uninformative
/// stripe. A simple current-state card (percentage + charging status) is
/// more honest about what's actually worth showing at this timescale.
struct BatteryCard: View {
    let battery: BatterySnapshot

    private var systemImage: String {
        if battery.isCharging { return "battery.100.bolt" }
        switch battery.percentage {
        case ..<20: return "battery.25"
        case ..<60: return "battery.50"
        case ..<90: return "battery.75"
        default: return "battery.100"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(InkPalette.statusAccent)
                    .accessibilityHidden(true)
                Text("电池")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            Text("\(battery.percentage)%")
                .font(.title2.bold())
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(battery.isCharging ? "正在充电" : "使用电池供电")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .bentoCard()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    BatteryCard(battery: BatterySnapshot(percentage: 82, isCharging: true, isPresent: true))
        .padding()
}
