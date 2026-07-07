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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .foregroundStyle(state == .off ? Color.secondary : Color.accentColor)
                .imageScale(.large)
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch state {
        case .on: return "checkmark.square.fill"
        case .off: return "square"
        case .partial: return "minus.square.fill"
        }
    }
}
