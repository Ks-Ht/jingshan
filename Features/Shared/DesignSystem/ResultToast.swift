import SwiftUI

/// A lightweight top-anchored result banner ("已清理 X 项，释放 Y GB"),
/// auto-dismissing after a few seconds.
struct ResultToast: View {
    let message: String
    var systemImage: String = "checkmark.circle.fill"
    var tint: Color = .green

    var body: some View {
        Label {
            Text(message)
                .font(.callout.weight(.medium))
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
    }
}

/// Binds to an optional String: setting it non-nil presents the toast and
/// schedules auto-dismissal via `.task(id:)` (so a new message restarts the
/// dismiss timer rather than racing with the previous one); setting it back
/// to nil hides it early.
private struct ResultToastModifier: ViewModifier {
    @Binding var message: String?
    var tint: Color
    var systemImage: String
    var autoDismissAfter: Duration

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let message {
                ResultToast(message: message, systemImage: systemImage, tint: tint)
                    .padding(.top, 12)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    .task(id: message) {
                        try? await Task.sleep(for: autoDismissAfter)
                        if !Task.isCancelled { self.message = nil }
                    }
            }
        }
        .animation(MotionEnvironment.animation(.easeOut(duration: 0.25), reduceMotion: reduceMotion), value: message)
        // A transient overlay appearing/disappearing doesn't reliably reach
        // VoiceOver on its own since it never takes keyboard focus — post an
        // explicit announcement so "cleanup succeeded" is actually heard.
        .onChange(of: message) { _, newValue in
            guard let newValue else { return }
            AccessibilityNotification.Announcement(newValue).post()
        }
    }
}

extension View {
    func resultToast(
        message: Binding<String?>,
        tint: Color = .green,
        systemImage: String = "checkmark.circle.fill",
        autoDismissAfter: Duration = .seconds(3)
    ) -> some View {
        modifier(ResultToastModifier(message: message, tint: tint, systemImage: systemImage, autoDismissAfter: autoDismissAfter))
    }
}
