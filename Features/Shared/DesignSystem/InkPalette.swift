import SwiftUI
import AppKit

extension Color {
    /// A color resolved dynamically from separate light/dark values via
    /// `NSColor`'s dynamic-provider initializer — the same mechanism system
    /// colors use, so it participates correctly in SwiftUI's color-scheme
    /// switching without any `@Environment(\.colorScheme)` plumbing at call
    /// sites.
    init(light: NSColor, dark: NSColor) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// The ink-wash design system's color tokens. Neutrals (ink/paper/hairline)
/// and per-module accents are Swift constants rather than an Asset Catalog
/// colorset — this project already treats config as code (`project.yml` is
/// the sole hand-edited project source; JSON resources back the safety
/// denylists) rather than Xcode-managed opaque files, and the existing
/// `Assets.xcassets` `AccentColor` slot is an unused placeholder today, so
/// there's no existing asset-driven convention this would break.
///
/// Dark-mode values below are a first-pass brightening of the spec's
/// light-mode hexes (the design brief only pinned light-mode colors and
/// left dark "adjustable") — treat them as a starting point that needs a
/// real look in dark mode, not as spec-derived values.
enum InkPalette {
    static let ink = Color(light: NSColor(hex: 0x2B2B2E), dark: NSColor(hex: 0xEDEDEF))
    /// Warm off-white page background (宣纸米白).
    static let paper = Color(light: NSColor(hex: 0xFBFAF7), dark: NSColor(hex: 0x1A1B1E))
    /// Card surface — a touch whiter than `paper` so cards lift off the page.
    static let card = Color(light: NSColor(hex: 0xFFFFFF), dark: NSColor(hex: 0x242529))
    static let hairline = Color(light: NSColor(hex: 0xE6E3DC), dark: NSColor(hex: 0x2E2F33))

    /// Brand/primary accent — the ink-green (松绿) that leads the whole app:
    /// top-nav selection, the home health-check hero, primary buttons.
    static let accent = Color(light: NSColor(hex: 0x3F6B57), dark: NSColor(hex: 0x6FA98F))

    /// Clean module shares the brand green (the module and the brand are the
    /// same color, matching the reference design).
    static let cleanAccent = accent
    static let dockerAccent = Color(light: NSColor(hex: 0x4A6FA5), dark: NSColor(hex: 0x6B8DBE))
    static let purgeAccent = Color(light: NSColor(hex: 0xB5713B), dark: NSColor(hex: 0xC98950))
    static let uninstallerAccent = Color(light: NSColor(hex: 0xC0503F), dark: NSColor(hex: 0xD37058))
    static let statusAccent = Color(light: NSColor(hex: 0xC69A34), dark: NSColor(hex: 0xDDB65A))

    /// A cool cyan (花青) used as the "healthy" tint for the disk usage bar on
    /// the home overview — distinct from CPU's green so the three bars read as
    /// three different metrics at a glance.
    static let coolCyan = Color(light: NSColor(hex: 0x3E7C8C), dark: NSColor(hex: 0x5A9AAA))
    /// Escalation tints for usage bars (amber 70–90%, vermilion ≥90%).
    static let amber = Color(light: NSColor(hex: 0xC08A2E), dark: NSColor(hex: 0xD6A94E))
    static let vermilion = uninstallerAccent
}
