import SwiftUI

/// The top-nav destinations. Replaces the old `SidebarItem` +
/// `NavigationSplitView` sidebar — navigation now lives in a custom top bar
/// (`TopNavBar`) with state-driven content switching in `RootView`, with a
/// new `home` landing tab in front of the five feature modules.
enum AppTab: String, CaseIterable, Identifiable {
    case home
    case clean
    case docker
    case purge
    case uninstall
    case largeFiles
    case status

    var id: String { rawValue }

    /// The short label shown in the top nav (Uninstall is "卸载" here, but its
    /// module page/tile use the fuller "卸载应用").
    var title: String {
        switch self {
        case .home: return "首页"
        case .clean: return "清理"
        case .docker: return "Docker"
        case .purge: return "构建产物"
        case .uninstall: return "卸载"
        case .largeFiles: return "大文件"
        case .status: return "状态"
        }
    }

    /// Each feature keeps one consistent identity color; the home tab uses the
    /// brand accent since it has no single module color of its own.
    var tint: Color {
        switch self {
        case .home: return InkPalette.accent
        case .clean: return InkPalette.cleanAccent
        case .docker: return InkPalette.dockerAccent
        case .purge: return InkPalette.purgeAccent
        case .uninstall: return InkPalette.uninstallerAccent
        case .largeFiles: return InkPalette.coolCyan
        case .status: return InkPalette.statusAccent
        }
    }

    /// SF Symbol for the module tiles on the home page (the nav bar itself is
    /// text-only, matching the reference design).
    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .clean: return "sparkles"
        case .docker: return "shippingbox.fill"
        case .purge: return "hammer.fill"
        case .uninstall: return "trash.fill"
        case .largeFiles: return "doc.viewfinder.fill"
        case .status: return "waveform.path.ecg"
        }
    }
}
