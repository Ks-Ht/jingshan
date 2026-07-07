import AppKit
import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case clean
    case docker
    case purge
    case uninstaller
    case status

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clean: return "清理"
        case .docker: return "Docker"
        case .purge: return "构建产物"
        case .uninstaller: return "卸载应用"
        case .status: return "状态"
        }
    }

    var systemImage: String {
        switch self {
        case .clean: return "trash"
        case .docker: return "shippingbox"
        case .purge: return "archivebox"
        case .uninstaller: return "minus.app"
        case .status: return "waveform.path.ecg"
        }
    }

    /// Each feature keeps one consistent identity color, used for its
    /// sidebar icon and echoed in that page's own header/primary button —
    /// a lightweight version of Mole's per-tool color identity.
    var tint: Color {
        switch self {
        case .clean: return .green
        case .docker: return .blue
        case .purge: return .orange
        case .uninstaller: return .pink
        case .status: return .teal
        }
    }
}

/// A custom sidebar rather than `List(selection:)` — a "trail" threads
/// behind the waypoint badges connecting each destination, and the active
/// one lifts slightly, like having arrived at that stop on a route. Traded
/// away `List`'s free keyboard/accessibility plumbing for that layout
/// control; each row is still a real `Button`, so Tab/Space/Return keep
/// working.
struct SidebarView: View {
    @Binding var selection: SidebarItem?

    private let rowHeight: CGFloat = 34
    private let rowSpacing: CGFloat = 3
    private let badgeCenterX: CGFloat = 19

    private var trailHeight: CGFloat {
        let count = CGFloat(SidebarItem.allCases.count)
        return count * rowHeight + (count - 1) * rowSpacing
    }

    var body: some View {
        VStack(spacing: 0) {
            sidebarBrandHeader

            ZStack(alignment: .top) {
                Path { path in
                    path.move(to: CGPoint(x: badgeCenterX, y: rowHeight / 2))
                    path.addLine(to: CGPoint(x: badgeCenterX, y: trailHeight - rowHeight / 2))
                }
                .stroke(Color(nsColor: .tertiaryLabelColor), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))

                VStack(spacing: rowSpacing) {
                    ForEach(SidebarItem.allCases) { item in
                        SidebarRow(item: item, isSelected: selection == item, height: rowHeight) {
                            selection = item
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)

            Spacer(minLength: 12)
        }
        .frame(minWidth: 190, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial)
        .navigationSplitViewColumnWidth(min: 190, ideal: 212)
    }

    private var sidebarBrandHeader: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 22, height: 22)
            Text("净山")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

private struct SidebarRow: View {
    let item: SidebarItem
    let isSelected: Bool
    let height: CGFloat
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6.5)
                        .fill(item.tint.gradient)
                        .frame(width: 22, height: 22)
                    Image(systemName: item.systemImage)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(isSelected ? 1.14 : 1.0)
                .shadow(color: .black.opacity(isSelected ? 0.28 : 0.15), radius: isSelected ? 3 : 1, y: 1)

                Text(item.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: height)
            .background(
                isSelected ? Color.primary.opacity(0.08) : (isHovering ? Color.primary.opacity(0.05) : Color.clear),
                in: RoundedRectangle(cornerRadius: 7)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}
