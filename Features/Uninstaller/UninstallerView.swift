import AppKit
import JingshanCore
import SwiftUI

struct UninstallerView: View {
    @State private var viewModel = UninstallerViewModel()
    @State private var searchText = ""
    @State private var showingConfirmation = false

    private var filteredApps: [InstalledApplication] {
        guard !searchText.isEmpty else { return viewModel.installedApps }
        return viewModel.installedApps.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        HStack(spacing: 0) {
            appListColumn
            Divider()
            detailColumn
        }
        .navigationTitle("卸载应用")
        .task {
            if viewModel.installedApps.isEmpty {
                viewModel.startScan()
            }
        }
        .sheet(isPresented: $showingConfirmation) {
            // These are snapshots taken at presentation time, not live
            // bindings — safe only because the residual checkboxes live in
            // `detailColumn`, which SwiftUI makes unreachable while this
            // modal sheet is up. If the residual list is ever moved inside
            // the sheet itself (or presented non-modally), this must become
            // a live binding, or `acknowledgedDestructive` could stay valid
            // against a selection the user changed after acknowledging it.
            UninstallerConfirmationSheet(
                appName: viewModel.selectedApp?.displayName ?? "",
                selectedCount: viewModel.selectedItemCount,
                totalBytes: viewModel.totalSelectedBytes,
                hasDestructiveSelection: viewModel.hasDestructiveSelection,
                onConfirm: { permanently in
                    showingConfirmation = false
                    Task { await viewModel.performUninstall(permanently: permanently) }
                },
                onCancel: { showingConfirmation = false }
            )
        }
        .alert(
            viewModel.lastUninstallSummary?.dryRun == true ? "预览结果（未实际卸载）" : "卸载完成",
            isPresented: Binding(
                get: { viewModel.lastUninstallSummary != nil },
                set: { if !$0 { viewModel.lastUninstallSummary = nil } }
            )
        ) {
            Button("好") { viewModel.lastUninstallSummary = nil }
        } message: {
            if let summary = viewModel.lastUninstallSummary {
                Text(summaryMessage(summary))
            }
        }
    }

    private var appListColumn: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("搜索应用", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                if viewModel.isScanningApps {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("刷新") { viewModel.startScan() }
                }
            }
            .padding(10)

            Divider()

            if filteredApps.isEmpty {
                ContentUnavailableView(
                    viewModel.isScanningApps ? "正在扫描已安装的应用…" : "没有找到应用",
                    systemImage: "app.dashed"
                )
                .frame(maxHeight: .infinity)
            } else {
                List(filteredApps, selection: appSelectionBinding) { app in
                    UninstallerAppRow(app: app).tag(app.id)
                }
            }
        }
        .frame(minWidth: 260, idealWidth: 280, maxWidth: 340)
    }

    private var appSelectionBinding: Binding<String?> {
        Binding(
            get: { viewModel.selectedApp?.id },
            set: { newID in
                guard let newID, let app = viewModel.installedApps.first(where: { $0.id == newID }) else { return }
                viewModel.selectApp(app)
            }
        )
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let app = viewModel.selectedApp {
            VStack(alignment: .leading, spacing: 0) {
                detailHeader(for: app)
                Divider()
                if let verdict = viewModel.selectedAppProtectionVerdict, !isNotProtected(verdict) {
                    protectionWarning(for: verdict)
                }
                if viewModel.isScanningResiduals {
                    ProgressView("正在查找残留文件…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.residualCandidates.isEmpty {
                    ContentUnavailableView("没有找到残留文件", systemImage: "checkmark.circle", description: Text("只会卸载应用本体。"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.residualCandidates) { candidate in
                        ResidualCandidateRow(candidate: candidate, viewModel: viewModel)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "选择一个应用",
                systemImage: "minus.app",
                description: Text("从左侧列表选择要卸载的应用，会自动查找它在其他位置留下的文件。")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func detailHeader(for app: InstalledApplication) -> some View {
        HStack(spacing: 18) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                .resizable()
                .frame(width: 64, height: 64)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.displayName).font(.system(size: 16, weight: .bold))
                Text(app.bundleIdentifier).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            StatDisplay(value: ByteFormatter.string(fromBytes: viewModel.totalSelectedBytes), label: "将处理的大小")
            Button("卸载…") { showingConfirmation = true }
                .buttonStyle(.borderedProminent)
                .tint(SidebarItem.uninstaller.tint)
                .disabled(!viewModel.canUninstallSelectedApp)
        }
        .padding()
        .background(HeroHeaderWash(tint: SidebarItem.uninstaller.tint))
    }

    private func isNotProtected(_ verdict: ProtectionEvaluator.Verdict) -> Bool {
        if case .notProtected = verdict { return true }
        return false
    }

    private func protectionWarning(for verdict: ProtectionEvaluator.Verdict) -> some View {
        Group {
            switch verdict {
            case .runningApp:
                Label("该应用正在运行，请先退出后再卸载。", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            case .staticallyProtected(let reason):
                Label("该应用受保护，无法卸载：\(reason)", systemImage: "lock.fill")
                    .foregroundStyle(.red)
            case .notProtected:
                EmptyView()
            }
        }
        .font(.callout)
        .padding()
    }

    private func summaryMessage(_ summary: CleanupSummary) -> String {
        let sizeVerb = summary.dryRun ? "预计可释放" : "释放"
        let countVerb = summary.dryRun ? "将处理" : "已处理"
        var parts = ["\(sizeVerb) \(ByteFormatter.string(fromBytes: summary.freedBytes))", "\(countVerb) \(summary.deletedCount) 项"]
        if summary.skippedCount > 0 {
            parts.append("跳过 \(summary.skippedCount) 项")
        }
        if summary.failedCount > 0 {
            parts.append("失败 \(summary.failedCount) 项")
        }
        return parts.joined(separator: "，")
    }
}

#Preview {
    UninstallerView()
}
