import SwiftUI

/// Generic card container: 12pt corner radius, secondary background, a
/// shadow subtle enough to separate layers without looking like a sticker.
/// Used to wrap grouped list sections, Bento tiles, and similar chrome.
struct SectionCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
    }
}
