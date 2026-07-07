import Charts
import SwiftUI

/// A quiet ~60-second trend line for a Bento card — thin stroke, module-tint
/// gradient fill, no axes/labels (the big number above it already carries
/// the current value; this is purely "which way has it been moving").
struct Sparkline: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        if values.count > 1 {
            Chart(Array(values.enumerated()), id: \.offset) { index, value in
                LineMark(x: .value("t", index), y: .value("v", value))
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("t", index), y: .value("v", value))
                    .foregroundStyle(.linearGradient(colors: [tint.opacity(0.22), tint.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: sparklineDomain)
            .clipped() // AreaMark fills can paint past the chart's frame; clip so they can't bleed down the card
        } else {
            // Not enough samples yet for a meaningful line — a flat hairline
            // reads as "collecting data" rather than an empty gap.
            Rectangle()
                .fill(InkPalette.hairline)
                .frame(height: 1)
        }
    }

    /// Padding the domain slightly so a flat-line reading (e.g. steady 0%
    /// network traffic) doesn't render as a line glued to the frame's edge.
    private var sparklineDomain: ClosedRange<Double> {
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        guard high > low else { return (low - 1)...(low + 1) }
        let pad = (high - low) * 0.15
        return (low - pad)...(high + pad)
    }
}
