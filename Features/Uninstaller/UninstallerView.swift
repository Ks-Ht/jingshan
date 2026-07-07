import AppKit
import JingshanCore
import SwiftUI

private enum AppSortOrder: String, CaseIterable, Identifiable {
    case name
    case size

    var id: String { rawValue }
    var title: String {
        switch self {
        case .name: return "按名称"
        case .size: return "按大小"
        }
    }
}

struct UninstallerView: View {
    let viewModel: UninstallerViewModel
    @State private var searchText = ""
    @State private var sortOrder: AppSortOrder = .name
    @State private var showingConfirmation = false
    @State private var acknowledgedDestructive = false

    private var filteredApps: [InstalledApplication] {
        let base = searchText.isEmpty
            ? viewModel.installedApps
            : viewModel.installedApps.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
        switch sortOrder {
        case .name:
            return base.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        case .size:
            return base.sorted { ($0.sizeBytes ?? 0) > ($1.sizeBytes ?? 0) }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            appListColumn
            Divider()
            detailColumn
        }
        .navigationTitle("卸载应用")
        .tint(InkPalette.uninstallerAccent)
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
            // a live binding, or the acknowledgment toggles could stay valid
            // against a selection the user changed after acknowledging it.
            ConfirmSheetShell(
                title: "确认卸载「\(viewModel.selectedApp?.displayName ?? "")」",
                items: confirmItems,
                totalSizeText: ByteFormatter.string(fromBytes: viewModel.totalSelectedBytes),
                extraAcknowledgment: { _ in
                    UninstallerDestructiveAcknowledgment(
                        hasDestructiveSelection: viewModel.hasDestructiveSelection,
                        acknowledged: $acknowledgedDestructive
                    )
                },
                extraAcknowledgmentSatisfied: { _ in !viewModel.hasDestructiveSelection || acknowledgedDestructive },
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
            if let summary = viewModel.lastUninstallSummary, !summary.dryRun, summary.freedBytes > 0 {
                Button("打开废纸篓") {
                    SystemActions.openTrash()
                    viewModel.lastUninstallSummary = nil
                }
            }
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
                Text("已安装的应用").font(.headline)
                Spacer()
                Picker("排序", selection: $sortOrder) {
                    ForEach(AppSortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 100)
                if viewModel.isScanningApps {
                    ProgressView().controlSize(.small)
                } else {
                    // Neutral, not the module red — red is reserved for the
                    // destructive "卸载" action so refresh doesn't read as risky.
                    Button("刷新") { viewModel.startScan() }
                        .tint(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 8)

            // Search lives here, inside the list column — not via `.searchable`,
            // which macOS floats up into the window title bar where it collided
            // with the top tab navigation. Themed (module accent via the view's
            // `.tint`), no system-blue focus ring.
            searchField
                .padding(.horizontal, 10)
                .padding(.bottom, 8)

            Divider()

            if filteredApps.isEmpty {
                if viewModel.isScanningApps {
                    ScanningStateView(statusText: "正在扫描已安装的应用…")
                        .padding(24)
                        .frame(maxHeight: .infinity)
                } else {
                    EmptyStateView(systemImage: "app.dashed", title: "没有找到应用", message: "换个关键词试试，或者刷新一下列表。")
                        .frame(maxHeight: .infinity)
                }
            } else {
                // Custom selection (accent-soft fill + a left accent bar)
                // instead of `List(selection:)`'s macOS default bright-blue
                // full-row highlight, which clashes with the ink palette.
                // Each row is a real Button, so it stays keyboard-focusable.
                List(filteredApps) { app in
                    Button { viewModel.selectApp(app) } label: {
                        UninstallerAppRow(app: app)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(rowBackground(isSelected: viewModel.selectedApp?.id == app.id))
                    .accessibilityAddTraits(viewModel.selectedApp?.id == app.id ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
        .frame(minWidth: 260, idealWidth: 280, maxWidth: 340)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("搜索应用", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(InkPalette.hairline, lineWidth: 0.5))
    }

    private func rowBackground(isSelected: Bool) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(isSelected ? InkPalette.uninstallerAccent : Color.clear)
                .frame(width: 3)
            (isSelected ? InkPalette.uninstallerAccent.opacity(0.12) : Color.clear)
        }
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
                    ScanningStateView(statusText: "正在查找残留文件…")
                        .padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.residualCandidates.isEmpty {
                    EmptyStateView(systemImage: "checkmark.circle", title: "没有找到残留文件", message: "只会卸载应用本体。")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.residualCandidates) { candidate in
                        ResidualCandidateRow(candidate: candidate, viewModel: viewModel)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyStateView(
                systemImage: "minus.app",
                title: "选择一个应用",
                message: "从左侧列表选择要卸载的应用，会自动查找它在其他位置留下的文件。"
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
            Button("卸载…") {
                acknowledgedDestructive = false // fresh acknowledgment required for every new confirm-sheet presentation
                showingConfirmation = true
            }
            .buttonStyle(.borderedProminent)
            .tint(InkPalette.uninstallerAccent)
            .disabled(!viewModel.canUninstallSelectedApp)
        }
        .padding()
        .background(InkPalette.paper) // clean; the old corner radial "wash" blob was removed per the ink-wash cleanup
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
                    .foregroundStyle(RiskTint.caution)
            case .staticallyProtected(let reason):
                Label("该应用受保护，无法卸载：\(reason)", systemImage: "lock.fill")
                    .foregroundStyle(RiskTint.destructive)
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

    /// The app itself (if any) plus every currently-selected residual,
    /// mirroring exactly what `viewModel.selectedItemCount`/`totalSelectedBytes`
    /// already count — a snapshot at sheet-presentation time, per the safety
    /// note on the `.sheet` modifier above.
    private var confirmItems: [UninstallerConfirmItem] {
        var items: [UninstallerConfirmItem] = []
        if let app = viewModel.selectedApp {
            items.append(.app(app))
        }
        items.append(contentsOf: viewModel.residualCandidates
            .filter { viewModel.selectedResidualIDs.contains($0.id) }
            .map(UninstallerConfirmItem.residual))
        return items
    }
}

#Preview {
    UninstallerView(viewModel: UninstallerViewModel())
}

private enum UninstallerConfirmItem: ConfirmSheetItem {
    case app(InstalledApplication)
    case residual(ResidualCandidate)

    var id: String {
        switch self {
        case .app(let app): return "app-\(app.id)"
        case .residual(let candidate): return candidate.id
        }
    }

    var displayName: String {
        switch self {
        case .app(let app): return "\(app.displayName)（应用本体）"
        case .residual(let candidate): return candidate.displayLabel
        }
    }

    var sizeText: String? {
        switch self {
        case .app(let app): return app.sizeBytes.map(ByteFormatter.string(fromBytes:))
        case .residual(let candidate): return candidate.sizeBytes.map(ByteFormatter.string(fromBytes:))
        }
    }

    var riskBadge: CategoryRowRisk? {
        switch self {
        case .app: return nil
        case .residual(let candidate): return candidate.tier.categoryRowRisk
        }
    }
}

/// Uninstaller's destructive-tier gate (sandbox container data may be real
/// app data, not just cache) — same copy and behavior as the old
/// `UninstallerConfirmationSheet`'s inline branch, relocated so
/// `ConfirmSheetShell` can inject it via `extraAcknowledgment`.
private struct UninstallerDestructiveAcknowledgment: View {
    let hasDestructiveSelection: Bool
    @Binding var acknowledged: Bool

    var body: some View {
        if hasDestructiveSelection {
            VStack(alignment: .leading, spacing: 8) {
                Label("包含沙盒容器数据（可能是应用的实际数据而非仅缓存），请确认后再继续。", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(RiskTint.irreversible)
                    .font(.callout)
                Toggle("我确认这些容器数据不再需要", isOn: $acknowledged)
            }
        }
    }
}
