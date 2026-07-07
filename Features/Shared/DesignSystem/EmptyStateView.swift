import SwiftUI

/// Generic empty state: centered large SF Symbol + title + a short
/// actionable message + an optional primary button. Consolidates each
/// module's own ad hoc `ContentUnavailableView` usage into one consistently
/// styled component.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.6))
                .accessibilityHidden(true) // redundant with the title/message text below
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .padding(32)
        .frame(maxWidth: 360)
    }
}
