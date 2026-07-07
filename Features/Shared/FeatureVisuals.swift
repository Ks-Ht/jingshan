import SwiftUI

/// Small shared visual primitives used across Clean/Docker/Purge/Uninstaller
/// so every page's header reads the same way at a glance, instead of each
/// screen inventing its own layout. Deliberately just visual chrome, not a
/// do-everything header component — each page still assembles its own
/// buttons/logic, since those genuinely differ (e.g. Docker has no separate
/// "reclaimable" stat, Uninstaller has no batch selection).
struct FeatureIconBadge: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.title2)
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
    }
}

/// A big-number stat paired with a small caption, e.g. "12.3 GB" / "共可清理".
/// Mirrors Mole's own review screens, which lead with the byte count rather
/// than burying it in a sentence.
struct StatDisplay: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Semantic colors for risk/caution indicators, kept consistent across every
/// module's own risk vocabulary (Docker's safe/caution/destructive,
/// Uninstaller's safe/caution/destructive, Clean's isProtected, Purge's
/// isRecent) rather than each screen picking its own color ad hoc.
enum RiskTint {
    static let caution = Color.orange
    static let destructive = Color.red
}

/// Health-style coloring for the Status page's usage gauges (CPU/Memory/
/// Disk) — green while comfortable, shading through the same caution/
/// destructive tones used for deletion risk once usage gets high, echoing
/// Mole's "green for healthy, amber/red for warnings" status language.
enum SystemHealthTint {
    static func forUsagePercent(_ percent: Double) -> Color {
        switch percent {
        case ..<60: return .green
        case 60..<85: return RiskTint.caution
        default: return RiskTint.destructive
        }
    }
}

/// A semicircular "dome" gauge — the hero stat for Clean/Docker/Purge page
/// headers, showing what fraction of the reclaimable total is currently
/// selected. `Circle().trim` traces clockwise starting at 3 o'clock, so
/// trim(0.5...1.0) alone already draws exactly the upper dome (9 o'clock via
/// 12 to 3 o'clock) with no angle math to get backwards.
struct ArcGauge: View {
    let valueText: String
    let captionText: String
    let fraction: Double
    let tint: Color

    private let diameter: CGFloat = 100
    private let lineWidth: CGFloat = 9

    private var clampedFraction: Double { max(0, min(1, fraction)) }

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.5, to: 1.0)
                .stroke(Color.primary.opacity(0.1), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: diameter, height: diameter)
            Circle()
                .trim(from: 0.5, to: 0.5 + clampedFraction * 0.5)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: diameter, height: diameter)
            VStack(spacing: 0) {
                Text(valueText)
                    .font(.system(size: 19, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                Text(captionText)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .offset(y: 15)
            .frame(width: diameter - lineWidth * 2)
        }
        .frame(width: diameter, height: diameter * 0.6, alignment: .top)
        .clipped()
    }
}

/// Stand-in for `ArcGauge` before a scan has ever run. An empty
/// reclaimable/selected total is ambiguous — it could mean "scanned and
/// found nothing" or "never scanned" — so this renders a neutral dashed
/// ring instead of a real "0 KB" fraction, at the same footprint so the
/// header doesn't jump once real data arrives.
struct ArcGaugePlaceholder: View {
    private let diameter: CGFloat = 100
    private let lineWidth: CGFloat = 9

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.5, to: 1.0)
                .stroke(Color.primary.opacity(0.1), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [1, 5]))
                .frame(width: diameter, height: diameter)
            Text("--")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.tertiary)
                .offset(y: 15)
        }
        .frame(width: diameter, height: diameter * 0.6, alignment: .top)
        .clipped()
    }
}

/// The soft corner-tucked radial wash behind a page's hero header — quiet
/// enough not to compete with the arc gauge for attention.
struct HeroHeaderWash: View {
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.16), tint.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 110
                    )
                )
                .frame(width: 220, height: 220)
                .position(x: proxy.size.width - 30, y: -60)
        }
        .allowsHitTesting(false)
    }
}
