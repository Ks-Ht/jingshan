import SwiftUI

enum TriState {
    case on
    case off
    case partial
}

/// SwiftUI's `Toggle` has no built-in tri-state style, so this is a small
/// button standing in for one — used for "select all in this group" where
/// the group can be fully, partially, or not at all selected.
struct TriStateCheckbox: View {
    let state: TriState
    /// Module accent for the checked/partial fill — `Color.accentColor` would
    /// paint system-blue and ignore the app's per-module color rule.
    var tint: Color = InkPalette.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .foregroundStyle(state == .off ? Color.secondary : tint)
                .imageScale(.large)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("全选本组")
        .accessibilityValue(state == .on ? "已全选" : state == .partial ? "已选部分" : "未选择")
    }

    private var iconName: String {
        switch state {
        case .on: return "checkmark.square.fill"
        case .off: return "square"
        case .partial: return "minus.square.fill"
        }
    }
}
