import SwiftUI

extension View {
    /// Uniform Bento-tile chrome for the Status page. The `.clipShape` is the
    /// load-bearing fix for the reported bug: SwiftUI `Charts` `AreaMark`
    /// fills can render past their own frame, so without clipping a card's
    /// area chart bled down the card and all the way to the window bottom.
    /// `minHeight` keeps tiles roughly the same size without ever clipping
    /// real content (content taller than the floor just grows the card).
    /// `maxHeight: .infinity` makes every card fill its `LazyVGrid` row height
    /// (which equals the tallest card in that row), so a shorter card — e.g.
    /// the health-score card, which has no sparkline — stretches to match its
    /// row-mates and their bottom edges align instead of sitting ragged.
    func bentoCard(minHeight: CGFloat = 150) -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: .infinity, alignment: .topLeading)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
