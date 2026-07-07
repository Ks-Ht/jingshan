import SwiftUI

/// A full circular usage ring, styled like Apple's activity rings — fill
/// starts at 12 o'clock and sweeps clockwise. Shared by CPU/Memory/Disk so
/// only one place computes the ring geometry.
struct MetricRing: View {
    let percent: Double
    let tint: Color
    var diameter: CGFloat = 74
    var lineWidth: CGFloat = 9

    private var clampedFraction: Double { max(0, min(1, percent / 100)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clampedFraction)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(percent.rounded()))%")
                .font(.system(size: diameter * 0.2, weight: .bold))
                .monospacedDigit()
        }
        .frame(width: diameter, height: diameter)
    }
}
