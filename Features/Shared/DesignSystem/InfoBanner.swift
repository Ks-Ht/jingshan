import SwiftUI

/// A native-feeling notice banner — `Label` + a tinted background — for
/// informational callouts that currently render as raw text/HStack (e.g.
/// Docker's "not running" notice). Not for risk warnings; use `RiskTint`
/// directly at the call site for anything risk-related, since this banner's
/// tint is meant to read as "FYI," not "warning."
struct InfoBanner: View {
    let systemImage: String
    let message: String
    let tint: Color
    var actionTitle: String?
    var action: (() -> Void)?
    /// Shows a small spinner in place of the action button — for banners
    /// that trigger an async action (e.g. "start Docker") and need to show
    /// it's in flight rather than silently dropping the button.
    var isLoading: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Label {
                Text(message)
                    .font(.callout)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
            }
            Spacer(minLength: 8)
            if isLoading {
                ProgressView().controlSize(.small)
            } else if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}
