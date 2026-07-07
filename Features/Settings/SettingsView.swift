import AppKit
import JingshanCore
import SwiftUI

struct SettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var exclusionSelection: String?
    @State private var purgePathSelection: String?

    var body: some View {
        Form {
            Section {
                Toggle("预览模式（Dry Run）", isOn: $settings.dryRunEnabled)
                Text("开启后，清理、Docker、构建产物操作都只会显示“将会清理什么”，不会真正删除任何东西。适合先确认一遍再动手。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Label("安全", systemImage: "lock.shield")
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
                    Text("未配置。默认扫描 ~/Projects、~/GitHub、~/dev 中存在的目录。添加自定义目录后，只扫描你配置的目录。")
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
                    .foregroundStyle(SidebarItem.purge.tint)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 560)
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
