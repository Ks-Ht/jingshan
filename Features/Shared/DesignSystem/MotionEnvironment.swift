import SwiftUI

/// Reduce-Motion-aware animation helpers, centralized so every view added
/// from M20 onward checks `accessibilityReduceMotion` the same way instead
/// of each call site re-deriving its own ternary (or forgetting to check at
/// all, which is how this codebase had zero Reduce Motion support before
/// this file existed).
enum MotionEnvironment {
    /// `animation` unless Reduce Motion is on, in which case `nil` — passing
    /// `nil` to `.animation(_:value:)` disables animation for that value's
    /// changes entirely.
    static func animation(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}

/// Row/card hover micro-highlight: background tint + a barely-there scale
/// bump. Reads Reduce Motion itself so callers don't have to thread it
/// through.
struct HoverHighlight: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background(isHovering ? Color.primary.opacity(0.05) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .scaleEffect(isHovering && !reduceMotion ? 1.005 : 1.0)
            .animation(MotionEnvironment.animation(.easeOut(duration: 0.12), reduceMotion: reduceMotion), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

extension View {
    func hoverHighlight() -> some View {
        modifier(HoverHighlight())
    }
}

/// Button press micro-feedback (scale down slightly while pressed), the
/// primary-action equivalent of `HoverHighlight` for rows.
struct ScalePressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1.0)
            .animation(MotionEnvironment.animation(.easeOut(duration: 0.12), reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}
