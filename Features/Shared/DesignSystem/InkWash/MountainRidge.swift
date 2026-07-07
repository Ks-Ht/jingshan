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
private let ridgeProfile: [CGFloat] = [0.66, 0.30, 0.52, 0.16, 0.46, 0.28, 0.58]

private func ridgePath(in rect: CGRect, closed: Bool) -> Path {
    let ys = ridgeProfile
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
    func path(in rect: CGRect) -> Path { ridgePath(in: rect, closed: true) }
}

struct MountainRidgeLine: Shape {
    func path(in rect: CGRect) -> Path { ridgePath(in: rect, closed: false) }
}

/// The composed silhouette used at the bottom of every hero: a faint filled
/// ridge with a slightly stronger ridge line on top, in the module tint.
struct MountainSilhouette: View {
    let tint: Color
    var height: CGFloat = 64

    var body: some View {
        ZStack(alignment: .bottom) {
            // Very faint fill (0.06) so action buttons read as floating on clean
            // paper, not sitting on a colored band; the thin ridge line carries
            // the shape.
            MountainRidge().fill(tint.opacity(0.06))
            MountainRidgeLine().stroke(tint.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
