import SwiftUI

/// Semantic colors for risk/caution indicators, kept consistent across every
/// module's own risk vocabulary (Docker's safe/caution/destructive,
/// Uninstaller's safe/caution/destructive, Clean's isProtected, Purge's
/// isRecent) rather than each screen picking its own color ad hoc. Ink-family
/// tones, not the neon system orange/red.
enum RiskTint {
    static let caution = Color(light: NSColor(hex: 0xB07018), dark: NSColor(hex: 0xD6A94E))
    static let destructive = Color(light: NSColor(hex: 0xB03A2E), dark: NSColor(hex: 0xE0605C))

    /// For irreversible/unrecoverable actions specifically (e.g. permanent
    /// delete confirmations) — deliberately a distinct red from
    /// `InkPalette.uninstallerAccent` (#C1553B), a low-saturation brand
    /// color for the Uninstaller module itself. If the same red meant both
    /// "this is the Uninstaller" and "this action can't be undone", the two
    /// signals would blur together.
    static let irreversible = Color(light: NSColor(hex: 0xD64541), dark: NSColor(hex: 0xE0605C))
}

/// Health-style coloring for usage gauges everywhere (Status cards, home
/// overview bars, per-core bars, menu-bar panel): the brand ink-green while
/// comfortable, amber from 70%, ink-red from 90%. ONE threshold pair for the
/// whole app — the health ring and the overview bars must never disagree
/// about whether the same number is fine.
enum SystemHealthTint {
    static func forUsagePercent(_ percent: Double) -> Color {
        switch percent {
        case ..<70: return InkPalette.accent
        case 70..<90: return RiskTint.caution
        default: return RiskTint.destructive
        }
    }
}
