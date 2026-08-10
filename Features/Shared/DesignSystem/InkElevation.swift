import SwiftUI

/// The surface/elevation system for the "墨韵" design language — one card
/// chrome for the whole app, replacing the three divergent treatments
/// (`homeCard` border+shadow, `bentoCard` quaternary fill, `SectionCard`).
///
/// The professional trick it encodes: **light mode lifts with shadows, dark
/// mode lifts with surface tint + a whisper of stroke** — shadows are nearly
/// invisible on dark backgrounds, so each scheme gets the cue that actually
/// reads. Radii and paddings sit on the 8pt-ish grid (14pt radius, 16pt pad).
struct InkCardModifier: ViewModifier {
    var padding: CGFloat = 16
    var radius: CGFloat = 14
    /// Bento-style sizing: reserve a floor and stretch to fill the grid row
    /// so row-mates' bottom edges align.
    var minHeight: CGFloat?
    var fillsHeight: Bool = false

    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
            .background(InkPalette.card)
            // Clip BEFORE the shadows: this both contains Charts `AreaMark`
            // bleed (the old bentoCard's load-bearing fix) and lets the
            // view-level shadows below render outside the clipped bounds.
            // The card fill is fully opaque, so the drop shadow traces the
            // rounded rect only — never the text inside it.
            .clipShape(shape)
            .overlay(
                shape.stroke(scheme == .dark ? Color.white.opacity(0.07) : InkPalette.hairline.opacity(0.6), lineWidth: 0.5)
            )
            // Dual shadow = ambient + key; tuned to be felt, not seen.
            .shadow(color: .black.opacity(scheme == .dark ? 0.30 : 0.05), radius: 1, y: 1)
            .shadow(color: .black.opacity(scheme == .dark ? 0.20 : 0.06), radius: 14, y: 6)
    }
}

/// Hover behavior for interactive cards: a gentle lift (scale + deeper key
/// shadow reads as "this is clickable" without shouting). Static under
/// Reduce Motion.
struct HoverLiftModifier: ViewModifier {
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering && !reduceMotion ? 1.005 : 1)
            .shadow(color: .black.opacity(hovering ? 0.07 : 0), radius: 16, y: 8)
            .onHover { hovering = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: hovering)
    }
}

extension View {
    /// The app-wide card chrome.
    func inkCard(padding: CGFloat = 16, radius: CGFloat = 14, minHeight: CGFloat? = nil, fillsHeight: Bool = false) -> some View {
        modifier(InkCardModifier(padding: padding, radius: radius, minHeight: minHeight, fillsHeight: fillsHeight))
    }

    /// Hover lift for clickable cards/tiles.
    func hoverLift() -> some View {
        modifier(HoverLiftModifier())
    }
}
