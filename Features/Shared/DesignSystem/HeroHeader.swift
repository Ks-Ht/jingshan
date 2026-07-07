import SwiftUI

/// The top "Hero" section of a module's unified page template: a single
/// faint far-mountain silhouette hugging the bottom edge, the module title +
/// poem vertically centered on the leading edge, and a trailing action slot.
///
/// Deliberately does NOT include the RingGauge "overview bar" — that's a
/// separate template section each module places directly below its
/// `HeroHeader` (Uninstaller's per-app detail page doesn't use this
/// Hero/RingGauge pairing at all).
///
/// The decoration is intentionally restrained: one clean ridge (see
/// `MountainSilhouette`), not the blurred colored blobs / scattered dots /
/// solid sun disks the earlier `InkWashCanvas` produced, which read as
/// smudges. Height is kept tight so the page leads with content, not chrome.
struct HeroHeader<Actions: View>: View {
    let motif: InkWashMotif
    let title: String
    let tint: Color
    @ViewBuilder var actions: Actions

    var body: some View {
        ZStack(alignment: .bottom) {
            MountainSilhouette(tint: tint, height: 60)

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.title2.bold())
                    Text(motif.poem)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine) // one "title, poem" element, not two swipe stops
                Spacer(minLength: 8)
                actions
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 88)
        .background(InkPalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview("HeroHeader") {
    VStack(spacing: 16) {
        HeroHeader(motif: .clean, title: "清理", tint: InkPalette.cleanAccent) {
            Button("重新扫描") {}.buttonStyle(.bordered)
        }
        HeroHeader(motif: .docker, title: "Docker", tint: InkPalette.dockerAccent) {
            Button("清理") {}.buttonStyle(.borderedProminent).tint(InkPalette.dockerAccent)
        }
    }
    .padding()
    .background(InkPalette.paper)
}
