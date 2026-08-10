import SwiftUI

/// The type scale for the "墨韵" design language. Two ideas carry the whole
/// look:
///
/// 1. **Metrics are display objects.** Big numbers (health score, bytes,
///    percentages) use the rounded design + heavy weight + monospaced digits,
///    so dashboards read at a glance and numbers never jitter as they update.
/// 2. **Everything else stays semantic.** Titles/body/captions map onto the
///    system text styles so Dynamic Type keeps working; only tracking and
///    weight are tuned.
///
/// Use these instead of ad-hoc `.font(.system(size:))` so the scale stays
/// consistent app-wide.
enum InkType {
    /// Hero metric — the one number a card exists to show.
    static func metric(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// Page title inside a hero header.
    static let heroTitle: Font = .system(size: 22, weight: .bold)
    /// The ink poem line under a hero title.
    static let poem: Font = .system(size: 12, weight: .regular)
    /// Card / section titles.
    static let cardTitle: Font = .headline
    /// Uppercase-style kicker above card content (used with `.textCase`).
    static let kicker: Font = .caption.weight(.semibold)
    /// Standard supporting copy.
    static let caption: Font = .caption
}

extension Text {
    /// Display treatment for metric numbers: rounded, bold, monospaced digits,
    /// smooth numeric transitions.
    func inkMetric(size: CGFloat, weight: Font.Weight = .bold) -> some View {
        self
            .font(InkType.metric(size, weight: weight))
            .monospacedDigit()
            .contentTransition(.numericText())
    }
}
