import SwiftUI

/// A complete circular progress ring — replaces the buggy semicircle
/// `ArcGauge`/`ArcGaugePlaceholder` (Clean/Docker/Purge headers) and the
/// Status page's separate `MetricRing`, unifying both call sites on one
/// correct geometry.
///
/// The old `ArcGauge` bug: its outer frame was forced to `diameter * 0.6`
/// tall (to show only the upper dome), but the centered value/caption text
/// was `.offset(y: 15)` from the ZStack's center — which sits at the
/// midpoint of the full `diameter`-tall circles, not the shrunken frame —
/// pushing the text past the clip boundary, where `.clipped()` cut it off.
/// Here the outer frame always matches the circles' own full bounding box on
/// both axes, so nothing laid out inside the ZStack can ever exceed it;
/// `.clipped()` is never applied because it's never needed.
struct RingGauge: View {
    /// 0...1. Out-of-range values are clamped rather than asserted — a
    /// caller computing this from live byte counts (e.g. a scan still
    /// catching up to a selection change) should never crash the UI over a
    /// transient out-of-range value.
    let progress: Double
    let valueText: String
    /// Nil renders no second line at all (e.g. a compact ring paired
    /// alongside its own separate label/sparkline) rather than an empty-but-
    /// present line that would waste vertical space and leave the value
    /// looking off-center.
    var captionText: String? = nil
    let tint: Color
    var diameter: CGFloat = 120
    var lineWidth: CGFloat = 10

    // Plain `.system(size:)` fonts don't respond to Dynamic Type on their
    // own (unlike the semantic styles — `.headline` etc — used elsewhere in
    // this app), and this size is derived from `diameter` rather than a
    // fixed constant, so it needs its own `@ScaledMetric` seeded in `init`
    // rather than a simple property default.
    @ScaledMetric private var valueFontSize: CGFloat
    @ScaledMetric private var captionFontSize: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var clampedProgress: Double { min(max(progress, 0), 1) }

    init(progress: Double, valueText: String, captionText: String? = nil, tint: Color, diameter: CGFloat = 120, lineWidth: CGFloat = 10) {
        self.progress = progress
        self.valueText = valueText
        self.captionText = captionText
        self.tint = tint
        self.diameter = diameter
        self.lineWidth = lineWidth
        self._valueFontSize = ScaledMetric(wrappedValue: diameter * 0.17)
        self._captionFontSize = ScaledMetric(wrappedValue: diameter * 0.09)
    }

    var body: some View {
        ZStack {
            // Tinted track (not neutral gray) so even an empty ring already
            // carries the module's color identity.
            Circle()
                .stroke(tint.opacity(0.13), lineWidth: lineWidth)
            // The progress arc fades from a lighter head to the full tint at
            // its tip — the gradient travels with the rotation, so the darkest
            // point is always the leading edge.
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [tint.opacity(0.45), tint]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * max(clampedProgress, 0.001))
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90)) // trim starts at 3 o'clock; rotate so it starts at 12
            VStack(spacing: 2) {
                Text(valueText)
                    .font(.system(size: valueFontSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let captionText {
                    Text(captionText)
                        .font(.system(size: captionFontSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            // Width-only constraint so long byte-count strings wrap/scale
            // instead of overrunning the ring's inner diameter — never a
            // height constraint, since nothing here needs one to avoid
            // overflow (that was the old component's actual mistake).
            .frame(width: diameter - lineWidth * 3)
        }
        .frame(width: diameter, height: diameter) // same value both axes: the fix, replacing the old `* 0.6`
        .animation(MotionEnvironment.animation(.easeOut(duration: 0.4), reduceMotion: reduceMotion), value: clampedProgress)
        // Otherwise VoiceOver reads valueText/captionText as two separate
        // elements with no indication either belongs to a progress ring.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(captionText.map { "\(valueText)，\($0)" } ?? valueText)
    }
}

/// Stand-in for `RingGauge` before a scan/sample has ever run — an empty
/// total is ambiguous (found nothing vs. never checked), so this renders a
/// neutral dashed ring instead of a real "0" value, at the same footprint so
/// the header doesn't jump once real data arrives. Replaces `ArcGaugePlaceholder`.
struct RingGaugePlaceholder: View {
    var diameter: CGFloat = 120
    var lineWidth: CGFloat = 10

    @ScaledMetric private var dashFontSize: CGFloat

    init(diameter: CGFloat = 120, lineWidth: CGFloat = 10) {
        self.diameter = diameter
        self.lineWidth = lineWidth
        self._dashFontSize = ScaledMetric(wrappedValue: diameter * 0.15)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(InkPalette.hairline, style: StrokeStyle(lineWidth: lineWidth, dash: [1, 6]))
            Text("--")
                .font(.system(size: dashFontSize, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("尚未扫描")
    }
}

#Preview("RingGauge states") {
    HStack(spacing: 24) {
        RingGauge(progress: 0.68, valueText: "3.2 GB", captionText: "/ 5.6 GB", tint: InkPalette.cleanAccent)
        RingGauge(progress: 0.12, valueText: "245.24 GB", captionText: "已选中 12%", tint: InkPalette.statusAccent)
        RingGaugePlaceholder()
    }
    .padding()
}
