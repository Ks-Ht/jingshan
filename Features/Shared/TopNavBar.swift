import AppKit
import SwiftUI

/// The window's top navigation bar: ink-mountain brand mark + "净山" on the
/// leading edge, left-aligned pill tabs, and a trailing "…" overflow menu
/// (Settings / About / Check-for-updates). Deliberately a custom bar rather
/// than the system `TabView` top style — the reference design wants
/// left-aligned soft-green selection pills, not the centered
/// preferences-window look.
///
/// The window uses `.windowStyle(.hiddenTitleBar)`, so the traffic-light
/// controls float over the top-left of this bar; `trafficLightInset` leaves
/// room for them.
struct TopNavBar: View {
    @Binding var selection: AppTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let trafficLightInset: CGFloat = 78

    var body: some View {
        // 12pt between the logo and the tab group (was 16) so the brand reads
        // as part of the same cluster.
        HStack(spacing: 12) {
            brand
            HStack(spacing: 4) {
                ForEach(AppTab.allCases) { tab in
                    TabPill(tab: tab, isSelected: selection == tab) {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                            selection = tab
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            overflowMenu
        }
        .padding(.leading, trafficLightInset)
        .padding(.trailing, 16)
        .padding(.vertical, 10)
        .frame(height: 52)
        .background(.regularMaterial)
    }

    /// A real menu with concrete destinations — not the earlier bare "…" that
    /// looked like an overflow menu but only opened Settings. `SettingsLink`
    /// works as a menu item; About and Check-for-updates are genuine actions.
    private var overflowMenu: some View {
        Menu {
            SettingsLink { Label("设置…", systemImage: "gearshape") }
            Divider()
            Button {
                NSApp.orderFrontStandardAboutPanel(nil)
            } label: {
                Label("关于净山", systemImage: "info.circle")
            }
            Button {
                if let url = URL(string: "https://github.com/Ks-Ht/jingshan/releases") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("检查更新…", systemImage: "arrow.triangle.2.circlepath")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 26)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("更多")
    }

    private var brand: some View {
        HStack(spacing: 7) {
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(InkPalette.accent)
            Text("净山")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("净山")
    }
}

private struct TabPill: View {
    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(tab.title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? InkPalette.accent : Color.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected
                        ? InkPalette.accent.opacity(0.14)
                        : (isHovering ? Color.primary.opacity(0.05) : Color.clear),
                    in: Capsule()
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
