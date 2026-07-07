import SwiftUI

/// A big-number stat paired with a small caption, e.g. "12.3 GB" / "将处理的大小".
/// Mirrors Mole's own review screens, which lead with the byte count rather
/// than burying it in a sentence. Used standalone (not folded into
/// `HeroHeader`) by Uninstaller's per-app detail header, which has its own
/// distinct two-column layout.
struct StatDisplay: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
