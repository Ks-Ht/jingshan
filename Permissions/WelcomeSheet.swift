import SwiftUI

/// First-run onboarding, shown once (gated by `AppSettings.hasCompletedOnboarding`).
/// Order follows the spec: welcome → what 净山 does / its safety promise →
/// request Full Disk Access → done. It never deletes anything itself; it just
/// sets expectations and points the user at the one permission the app needs.
struct WelcomeSheet: View {
    let hasFullDiskAccess: Bool
    let onOpenSettings: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                WelcomeContent(hasFullDiskAccess: hasFullDiskAccess, onOpenSettings: onOpenSettings)
                    .padding(28)
            }
            Divider()
            HStack {
                Spacer()
                Button("开始使用") { onFinish() }
                    .buttonStyle(.borderedProminent)
                    .tint(InkPalette.accent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 520, height: 560)
        .background(InkPalette.paper)
    }
}

/// The scrollable body of the welcome sheet, split out so the snapshot harness
/// can render it directly (an `ImageRenderer` won't lay out `ScrollView`
/// content offscreen).
struct WelcomeContent: View {
    let hasFullDiskAccess: Bool
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            safetyPromise
            permissionStep
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(InkPalette.accent)
                Text("欢迎使用净山")
                    .font(.title.bold())
            }
            Text("净山帮你清理缓存与垃圾、回收 Docker 磁盘、清理项目构建产物、干净卸载应用，并监控系统状态。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var safetyPromise: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("数据安全是第一位的", systemImage: "checkmark.shield.fill")
                .font(.headline)
                .foregroundStyle(InkPalette.accent)
            promiseRow("先扫描、列出确切清单和大小，由你逐项勾选确认后才会执行。")
            promiseRow("删除默认是「移到废纸篓」，可以随时找回；永久删除是需要你手动开启的高级选项。")
            promiseRow("系统关键路径、正在运行的应用数据等受保护位置，即使手动勾选也绝不触碰。")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InkPalette.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(InkPalette.hairline, lineWidth: 0.5))
    }

    private func promiseRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(InkPalette.accent)
                .font(.caption)
                .padding(.top, 2)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var permissionStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("完全磁盘访问权限", systemImage: hasFullDiskAccess ? "checkmark.seal.fill" : "lock.shield")
                .font(.headline)
                .foregroundStyle(hasFullDiskAccess ? InkPalette.accent : InkPalette.statusAccent)
            if hasFullDiskAccess {
                Text("已授权。净山可以正常扫描系统各处的缓存与残留。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("净山需要「完全磁盘访问权限」才能扫描 ~/Library/Caches、其他应用数据、日志等位置。没有它，扫描结果会为空或不准。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("在打开的列表里找到「净山」并打开开关，授权后需重启净山生效。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("打开系统设置授权") { onOpenSettings() }
                    .buttonStyle(.bordered)
                    .tint(InkPalette.statusAccent)
            }
        }
    }
}

#Preview {
    WelcomeSheet(hasFullDiskAccess: false, onOpenSettings: {}, onFinish: {})
}
