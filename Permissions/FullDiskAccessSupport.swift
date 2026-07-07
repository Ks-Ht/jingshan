import AppKit
import SwiftUI

/// Shared actions for the Full Disk Access flow, so the first-run welcome, the
/// persistent banner and the Settings entry all open the exact same system
/// pane and relaunch the same way.
enum PermissionActions {
    /// Deep-links straight to System Settings → Privacy & Security → Full Disk
    /// Access (the `Privacy_AllFiles` anchor), so the user lands on the right
    /// list instead of hunting for it.
    static func openFullDiskAccessSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else { return }
        NSWorkspace.shared.open(url)
    }

    /// TCC caches an app's Full Disk Access grant at launch, so a grant made
    /// while 净山 is running only takes effect after a restart. This relaunches
    /// a fresh instance and then quits the current one.
    static func relaunch() {
        let url = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}

/// A slim, persistent banner shown at the top of every tab whenever Full Disk
/// Access is missing. Deliberately not dismissible: without FDA the app reads
/// 0 bytes from most protected locations, so scans look empty/broken — the
/// banner must stay until the permission is actually granted.
struct FullDiskAccessBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(InkPalette.statusAccent)
                .font(.system(size: 15, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text("净山尚未获得「完全磁盘访问权限」")
                    .font(.subheadline.weight(.semibold))
                Text("没有该权限时，缓存、其他应用数据等大量位置会扫不到或读到 0，扫描结果不准。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button("打开系统设置") { PermissionActions.openFullDiskAccessSettings() }
                .buttonStyle(.borderedProminent)
                .tint(InkPalette.statusAccent)
            Button("已授权，重启") { PermissionActions.relaunch() }
                .buttonStyle(.bordered)
                .help("完全磁盘访问在启动时缓存，授权后需重启净山才能生效")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(InkPalette.statusAccent.opacity(0.08))
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("净山尚未获得完全磁盘访问权限，扫描结果可能不准。可打开系统设置授权，授权后重启生效。")
    }
}
