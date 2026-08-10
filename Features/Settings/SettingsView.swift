import AppKit
import JingshanCore
import SwiftUI

struct SettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var exclusionSelection: String?
    @State private var purgePathSelection: String?
    @State private var hasFullDiskAccess = FullDiskAccessChecker.hasFullDiskAccess()

    var body: some View {
        Form {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: hasFullDiskAccess ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(hasFullDiskAccess ? InkPalette.accent : InkPalette.statusAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hasFullDiskAccess ? "已授权" : "未授权")
                            .font(.callout.weight(.semibold))
                        Text(hasFullDiskAccess
                            ? "净山可以正常扫描系统各处的缓存与残留。"
                            : "没有该权限时，~/Library/Caches、其他应用数据等位置会扫不到或读到 0，扫描结果不准。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                if !hasFullDiskAccess {
                    HStack {
                        Button("打开系统设置") { PermissionActions.openFullDiskAccessSettings() }
                        Button("授权后重启净山") { PermissionActions.relaunch() }
                    }
                }
            } header: {
                Label("完全磁盘访问权限", systemImage: "lock.shield")
            }

            Section {
                Toggle("预览模式（Dry Run）", isOn: $settings.dryRunEnabled)
                Text("开启后，清理、Docker、构建产物操作都只会显示“将会清理什么”，不会真正删除任何东西。适合先确认一遍再动手。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Label("安全", systemImage: "lock.shield")
            }

            Section {
                Toggle("在菜单栏显示监控", isOn: $settings.menuBarEnabled)
                if settings.menuBarEnabled {
                    Picker("菜单栏图标", selection: $settings.menuBarShowsPercent) {
                        Text("山峰标志").tag(false)
                        Text("CPU 占用 %").tag(true)
                    }
                    .pickerStyle(.menu)
                }
                Text("开启后净山会常驻菜单栏，可随时查看 CPU/内存/磁盘/电池并快速打开主窗口；关闭窗口不退出。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Label("菜单栏", systemImage: "menubar.rectangle")
            }

            Section {
                if settings.excludedPaths.isEmpty {
                    Text("还没有受保护的路径。添加后，这些路径及其内容永远不会被清理。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    List(selection: $exclusionSelection) {
                        ForEach(settings.excludedPaths, id: \.self) { path in
                            Text(path)
                                .font(.callout)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .tag(path)
                        }
                    }
                    .frame(minHeight: 100, maxHeight: 160)
                }
                HStack {
                    Button("添加路径…") { addExclusionPath() }
                    Button("移除所选") {
                        if let exclusionSelection { settings.removeExclusion(path: exclusionSelection) }
                        exclusionSelection = nil
                    }
                    .disabled(exclusionSelection == nil)
                }
            } header: {
                Label("受保护路径（永不清理）", systemImage: "checkmark.shield")
            }

            Section {
                if settings.purgeScanPaths.isEmpty {
                    Text("未配置。默认扫描 ~/workspace、~/Projects、~/Developer、~/GitHub、~/dev 中存在的目录。添加自定义目录后，只扫描你配置的目录。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    List(selection: $purgePathSelection) {
                        ForEach(settings.purgeScanPaths, id: \.self) { path in
                            Text(path)
                                .font(.callout)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .tag(path)
                        }
                    }
                    .frame(minHeight: 80, maxHeight: 140)
                }
                HStack {
                    Button("添加目录…") { addPurgeScanPath() }
                    Button("移除所选") {
                        if let purgePathSelection { settings.removePurgeScanPath(purgePathSelection) }
                        purgePathSelection = nil
                    }
                    .disabled(purgePathSelection == nil)
                }
            } header: {
                Label("构建产物扫描目录", systemImage: "archivebox")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 560)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasFullDiskAccess = FullDiskAccessChecker.hasFullDiskAccess()
        }
        .alert(
            "受保护路径配置异常",
            isPresented: Binding(
                get: { settings.exclusionPersistenceError != nil },
                set: { if !$0 { settings.clearExclusionPersistenceError() } }
            )
        ) {
            Button("好") { settings.clearExclusionPersistenceError() }
        } message: {
            Text(settings.exclusionPersistenceError ?? "未知错误")
        }
    }

    private func addExclusionPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "选择一个永不清理的文件或文件夹"
        if panel.runModal() == .OK, let url = panel.url {
            settings.addExclusion(path: url.path)
        }
    }

    private func addPurgeScanPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "选择一个要扫描构建产物的项目根目录"
        if panel.runModal() == .OK, let url = panel.url {
            settings.addPurgeScanPath(url.path)
        }
    }
}

#Preview {
    SettingsView()
}
