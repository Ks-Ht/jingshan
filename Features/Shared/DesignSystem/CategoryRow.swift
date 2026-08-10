import SwiftUI

enum CategoryRowRisk {
    case caution
    case destructive

    var tint: Color {
        switch self {
        case .caution: return RiskTint.caution
        case .destructive: return RiskTint.destructive
        }
    }

    var icon: String {
        switch self {
        case .caution: return "exclamationmark.circle"
        case .destructive: return "exclamationmark.triangle.fill"
        }
    }

    /// For contexts with no separate risk-note text to fall back on (e.g.
    /// `ConfirmSheetShell`'s itemized list) — `CategoryRow` itself prefers
    /// its own `riskNote`/`disabledReason` text when available instead.
    var spokenDescription: String {
        switch self {
        case .caution: return "需要注意"
        case .destructive: return "高风险"
        }
    }
}

/// The unified checkbox + title/subtitle + trailing size row used across
/// Clean/Docker/Purge/Uninstaller's grouped lists. Takes primitives
/// (pre-formatted strings, plain closures) rather than being generic over
/// each module's own item type — a single row's presentation doesn't need
/// genericity, and this keeps `DesignSystem` decoupled from `JingshanCore`
/// (byte formatting stays a call-site concern, same convention `StatDisplay`
/// already used).
struct CategoryRow: View {
    let title: String
    var subtitle: String?
    var risk: CategoryRowRisk?
    var riskNote: String?
    /// Pre-formatted (e.g. via `ByteFormatter`); nil renders "大小未知".
    var sizeText: String?
    var isSelected: Bool
    var isDisabled: Bool = false
    var disabledReason: String?
    /// Module accent for the checkbox fill (macOS's native `.checkbox` style
    /// ignores `.tint`, rendering system-blue; this keeps checkmarks on-brand).
    var tint: Color = InkPalette.accent
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Toggle(isOn: Binding(get: { isSelected }, set: { onToggle($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(title)
                        if let risk {
                            // Decorative — its meaning is already spelled out
                            // in `riskNote`/`disabledReason`, which the
                            // combined accessibility label below includes.
                            Image(systemName: risk.icon)
                                .foregroundStyle(risk.tint)
                                .help(disabledReason ?? "")
                                .accessibilityHidden(true)
                        }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    if let riskNote {
                        Text(riskNote)
                            .font(.caption2)
                            .foregroundStyle(risk == .destructive ? RiskTint.destructive : .secondary)
                    }
                }
            }
            .toggleStyle(ModuleCheckboxToggleStyle(tint: tint, isDisabled: isDisabled))
            .disabled(isDisabled)
            // Explicit label so the trailing size (outside the Toggle's own
            // label content) reads as part of the same VoiceOver element,
            // rather than a separate fragment the user has to swipe to
            // separately — while `.accessibilityLabel` only customizes the
            // announced text, so the Toggle's native checked/unchecked +
            // double-tap-to-toggle semantics are preserved untouched.
            .accessibilityLabel(accessibilityLabel)

            Spacer()

            if let sizeText {
                Text(sizeText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                Text("大小未知")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
        .hoverHighlight()
    }

    private var accessibilityLabel: String {
        var parts = [title]
        if let disabledReason {
            parts.append(disabledReason)
        } else if let riskNote {
            parts.append(riskNote)
        }
        if let subtitle {
            parts.append(subtitle)
        }
        parts.append(sizeText ?? "大小未知")
        return parts.joined(separator: "，")
    }
}

/// A checkbox toggle whose checkmark uses a passed-in module tint. macOS's
/// native `.checkbox` toggle style paints with the system accent (blue) and
/// ignores SwiftUI `.tint(_:)`, which broke the app's "every module is its own
/// color, never system blue" rule — this restores control over the fill while
/// keeping the leading-checkbox layout and full toggle semantics.
struct ModuleCheckboxToggleStyle: ToggleStyle {
    var tint: Color
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            // The WHOLE row toggles, not just the tiny glyph; using a real
            // Button keeps keyboard/focus behavior that a raw tap gesture lost.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .imageScale(.large)
                    .foregroundStyle(checkboxColor(isOn: configuration.isOn))
                    .accessibilityHidden(true)
                configuration.label
                    .opacity(isDisabled ? 0.55 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private func checkboxColor(isOn: Bool) -> Color {
        if isDisabled { return Color.secondary.opacity(0.4) }
        return isOn ? tint : Color.secondary
    }
}
