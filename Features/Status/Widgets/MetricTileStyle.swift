import SwiftUI

/// Whether a Status tile is the large "most urgent" hero slot or one of the
/// smaller supporting tiles beside it. Which metric gets `.hero` is decided
/// dynamically by `StatusView`, not fixed per metric.
enum MetricTileStyle {
    case hero
    case compact
}

extension View {
    func metricTileBackground(style: MetricTileStyle) -> some View {
        self
            .padding(style == .hero ? 22 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
}
