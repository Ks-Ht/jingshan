import SwiftUI

extension View {
    /// Uniform Bento-tile chrome for the Status page — now a thin wrapper over
    /// the app-wide `inkCard` surface (elevated card, dual soft shadow) so
    /// Status tiles match Home cards instead of the old flat `.quaternary`
    /// wash. Semantics preserved from the original: the inner `.clipShape` is
    /// the load-bearing fix for Charts `AreaMark` fills painting past their
    /// frame, `minHeight` keeps tiles from collapsing, and `fillsHeight`
    /// stretches every card to its `LazyVGrid` row height so row-mates'
    /// bottom edges align.
    func bentoCard(minHeight: CGFloat = 150) -> some View {
        inkCard(minHeight: minHeight, fillsHeight: true)
    }
}
