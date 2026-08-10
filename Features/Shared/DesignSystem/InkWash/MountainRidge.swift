import SwiftUI

/// A single, clean far-mountain ridge — the whole ink-wash decoration now.
/// The earlier `InkWashCanvas` drew blurred colored blobs, scattered "leaf"
/// dots and solid sun disks that read as smudges rather than ink wash; per
/// the design feedback that was replaced with one restrained silhouette:
/// a gentle ridge line, filled faintly, hugging the hero's bottom edge.
///
/// Two shapes share the same peak profile: `MountainRidge` (closed, for a
/// faint fill) and `MountainRidgeLine` (open, for a crisp 1.5pt stroke of
/// just the ridge — not the box edges a filled shape's stroke would trace).
private let nearRidgeProfile: [CGFloat] = [0.66, 0.30, 0.52, 0.16, 0.46, 0.28, 0.58]
/// A second, gentler ridge sitting "behind" the near one — its peaks are
/// deliberately out of phase so the two lines never merge visually.
private let farRidgeProfile: [CGFloat] = [0.34, 0.52, 0.24, 0.44, 0.18, 0.50, 0.30]

private func ridgePath(_ ys: [CGFloat], in rect: CGRect, closed: Bool) -> Path {
    let n = ys.count
    var path = Path()
    let firstY = rect.minY + rect.height * ys[0]
    if closed {
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: firstY))
    } else {
        path.move(to: CGPoint(x: rect.minX, y: firstY))
    }
    for i in 1..<n {
        let x = rect.minX + rect.width * CGFloat(i) / CGFloat(n - 1)
        let y = rect.minY + rect.height * ys[i]
        let prevX = rect.minX + rect.width * CGFloat(i - 1) / CGFloat(n - 1)
        let prevY = rect.minY + rect.height * ys[i - 1]
        // Smooth undulation, no sharp solid triangles.
        path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: (prevX + x) / 2, y: prevY))
    }
    if closed {
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
    }
    return path
}

struct MountainRidge: Shape {
    var profile: [CGFloat] = nearRidgeProfile
    func path(in rect: CGRect) -> Path { ridgePath(profile, in: rect, closed: true) }
}

struct MountainRidgeLine: Shape {
    var profile: [CGFloat] = nearRidgeProfile
    func path(in rect: CGRect) -> Path { ridgePath(profile, in: rect, closed: false) }
}

/// The composed silhouette used at the bottom of every hero: two layered
/// ridges — a paler far ridge behind a slightly stronger near one — giving
/// the header quiet depth (远山淡, 近山浓), the classic ink-wash recession.
/// Both fills stay whisper-faint so action buttons float on clean paper.
struct MountainSilhouette: View {
    let tint: Color
    var height: CGFloat = 64

    var body: some View {
        ZStack(alignment: .bottom) {
            MountainRidge(profile: farRidgeProfile)
                .fill(tint.opacity(0.05))
                .frame(height: height * 0.82)
            MountainRidge()
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.10), tint.opacity(0.04)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            MountainRidgeLine()
                .stroke(tint.opacity(0.22), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
