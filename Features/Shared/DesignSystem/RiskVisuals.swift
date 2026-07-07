import SwiftUI

/// Semantic colors for risk/caution indicators, kept consistent across every
/// module's own risk vocabulary (Docker's safe/caution/destructive,
/// Uninstaller's safe/caution/destructive, Clean's isProtected, Purge's
/// isRecent) rather than each screen picking its own color ad hoc.
enum RiskTint {
    static let caution = Color.orange
    static let destructive = Color.red

    /// For irreversible/unrecoverable actions specifically (e.g. permanent
    /// delete confirmations) — deliberately a distinct red from
    /// `InkPalette.uninstallerAccent` (#C1553B), a low-saturation brand
    /// color for the Uninstaller module itself. If the same red meant both
    /// "this is the Uninstaller" and "this action can't be undone", the two
    /// signals would blur together.
    static let irreversible = Color(light: NSColor(hex: 0xD64541), dark: NSColor(hex: 0xE0605C))
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
