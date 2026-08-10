import SwiftUI

/// Skeleton-row loading state shown while a scan is in progress, instead of
/// a blank list or a bare spinner. Shown while a scan is in flight.
/// in the page's `HeroHeader` so the illustration animates while this shows.
struct ScanningStateView: View {
    var statusText: String?
    var rowCount: Int = 5

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<rowCount, id: \.self) { _ in
                SkeletonRow()
            }
            if let statusText {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }
}

private struct SkeletonRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.primary.opacity(0.06))
            .frame(height: 36)
            .overlay(shimmerOverlay.clipShape(RoundedRectangle(cornerRadius: 6)))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1
                }
            }
    }

    @ViewBuilder
    private var shimmerOverlay: some View {
        if reduceMotion {
            EmptyView()
        } else {
            GeometryReader { proxy in
                LinearGradient(
                    colors: [.clear, Color.primary.opacity(0.06), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: proxy.size.width * 0.6)
                .offset(x: shimmerPhase * proxy.size.width * 1.6)
            }
        }
    }
}

#Preview("ScanningStateView") {
    ScanningStateView(statusText: "正在扫描 12/48 项…")
        .padding()
}
