import JingshanCore
import SwiftUI

struct CleanView: View {
    let viewModel: CleanViewModel
    @State private var showingConfirmation = false
    @State private var showingEmptyTrashConfirmation = false
    @State private var showingStrongModeInfo = false

    var body: some View {
        // Full Disk Access is now surfaced globally by RootView's persistent
        // banner (and the first-run welcome), so this view no longer gates
        // itself — that avoided a doubled banner + onboarding on the Clean tab.
        scanContent
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.hasScannedOnce, !viewModel.displayGroups.isEmpty {
                selectionBar
            }
        }
        .navigationTitle("清理")
        .tint(InkPalette.cleanAccent) // module color for all controls here, not system blue
        .sheet(isPresented: $showingConfirmation) {
            ConfirmSheetShell(
                title: "确认清理",
                items: confirmItems,
                totalSizeText: ByteFormatter.string(fromBytes: viewModel.totalSelectedBytes),
                extraAcknowledgment: { _ in EmptyView() },
                tint: InkPalette.cleanAccent,
                onConfirm: { permanently in
                    showingConfirmation = false
                    Task { await viewModel.performCleanup(permanently: permanently) }
                },
                onCancel: { showingConfirmation = false }
            )
        }
        .confirmationDialog(
            "确定要清空废纸篓吗？此操作不可恢复。",
            isPresented: $showingEmptyTrashConfirmation,
            titleVisibility: .visible
        ) {
            Button("清空废纸篓", role: .destructive) {
                Task { await viewModel.emptyTrash() }
            }
            Button("取消", role: .cancel) {}
        }
        .alert(
            viewModel.lastCleanupSummary?.dryRun == true ? "预览结果（未实际删除）" : "清理完成",
            isPresented: Binding(
                get: { viewModel.lastCleanupSummary != nil },
                set: { if !$0 { viewModel.lastCleanupSummary = nil } }
            )
        ) {
            if let summary = viewModel.lastCleanupSummary, !summary.dryRun, summary.freedBytes > 0 {
                Button("打开废纸篓") {
                    SystemActions.openTrash()
                    viewModel.lastCleanupSummary = nil
                }
            }
            Button("好") { viewModel.lastCleanupSummary = nil }
        } message: {
            if let summary = viewModel.lastCleanupSummary {
                Text(summaryMessage(summary))
            }
        }
    }

    private var scanContent: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if viewModel.categories.isEmpty || (viewModel.isScanning && !hasAnyItems) {
                if viewModel.isScanning {
                    ScanningStateView(statusText: "首次扫描可能需要一些时间…")
                        .padding(24)
                } else {
                    EmptyStateView(
                        systemImage: "magnifyingglass",
                        title: "还没有扫描结果",
                        message: "点击“开始扫描”查看可清理的缓存、日志与废纸篓。",
                        actionTitle: "开始扫描",
                        action: { viewModel.startScan() }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if !hasAnyItems {
                EmptyStateView(
                    systemImage: viewModel.scanIssues.isEmpty ? "checkmark.circle" : "exclamationmark.triangle",
                    title: viewModel.scanIssues.isEmpty ? "没有发现可清理内容" : "扫描结果不完整",
                    message: viewModel.scanIssues.first?.message ?? "当前范围内没有发现缓存或日志。",
                    actionTitle: "重新扫描",
                    action: { viewModel.startScan() }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    if !viewModel.scanIssues.isEmpty { scanIssueBanner }
                    filterBar
                    if viewModel.filteredDisplayGroups.isEmpty && !showsTrash {
                        VStack(spacing: 8) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("没有符合筛选条件的项目")
                                .font(.headline)
                            Text("调整搜索词或切换筛选条件")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(viewModel.filteredDisplayGroups) { group in
                                CleanGroupSectionView(group: group, viewModel: viewModel)
                            }
                            if showsTrash, let trash = viewModel.trashCategory, let item = trash.items.first {
                                trashRow(item)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Items currently selected for cleanup, re-using the same real-world
    /// display names `displayGroups` already computes (rather than raw
    /// file paths) so the confirm sheet's itemized list reads the same way
    /// the list on screen does.
    private var confirmItems: [CleanConfirmItem] {
        viewModel.displayGroups.flatMap(\.items)
            .filter { viewModel.isSelected($0.item) }
            .map(CleanConfirmItem.init)
    }

    private var hasAnyItems: Bool {
        viewModel.categories.contains { !$0.items.isEmpty }
    }

    private var showsTrash: Bool {
        viewModel.listFilter == .all && viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            TextField("搜索名称或路径", text: Binding(get: { viewModel.query }, set: { viewModel.query = $0 }))
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 180, maxWidth: 280)
                .accessibilityLabel("搜索清理项目")
            Picker("筛选", selection: Binding(get: { viewModel.listFilter }, set: { viewModel.listFilter = $0 })) {
                ForEach(CleanListFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 390)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(InkPalette.card.opacity(0.65))
    }

    private var scanIssueBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(RiskTint.caution)
            VStack(alignment: .leading, spacing: 2) {
                Text("扫描完成，但结果可能不完整")
                    .font(.subheadline.weight(.semibold))
                Text(viewModel.scanIssues.first?.message ?? "部分区域无法读取")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("重试") { viewModel.startScan() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(RiskTint.caution.opacity(0.08))
        .accessibilityElement(children: .combine)
    }

    private var selectionBar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("已选择 \(viewModel.selectedItems.count) 项 · \(ByteFormatter.string(fromBytes: viewModel.totalSelectedBytes))")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Label("默认移到废纸篓，可从清理历史恢复", systemImage: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("检查并清理…") { showingConfirmation = true }
                .buttonStyle(.borderedProminent)
                .tint(InkPalette.cleanAccent)
                .disabled(viewModel.selectedItems.isEmpty || viewModel.isScanning || viewModel.isCleaning)
                .keyboardShortcut(.return, modifiers: [.command])
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private func trashRow(_ item: ScannableItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: CacheGroup.trash.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(CacheGroup.trash.displayName)
                    .font(.headline)
                Text(CacheGroup.trash.groupDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let sizeBytes = item.sizeBytes {
                Text(ByteFormatter.string(fromBytes: sizeBytes))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            // The one truly irreversible bulk action on this page — styled so.
            Button("清空废纸篓", role: .destructive) {
                showingEmptyTrashConfirmation = true
            }
            .tint(RiskTint.destructive)
            .disabled(viewModel.isCleaning || (item.sizeBytes ?? 0) == 0)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var header: some View {
        let reclaimable = viewModel.safeReclaimableBytes
        let selected = viewModel.totalSelectedBytes
        let fraction = reclaimable > 0 ? min(Double(selected) / Double(reclaimable), 1) : 0

        VStack(spacing: 16) {
            HeroHeader(motif: .clean, title: "清理", tint: InkPalette.cleanAccent) {
                HStack(spacing: 10) {
                    if viewModel.isScanning {
                        ProgressView().controlSize(.small)
                        Button("取消") { viewModel.cancelScan() }
                    } else {
                        Button("开始扫描") { viewModel.startScan() }
                            .disabled(viewModel.isCleaning)
                    }
                }
            }

            HStack(spacing: 20) {
                if viewModel.hasScannedOnce {
                    RingGauge(
                        progress: fraction,
                        valueText: ByteFormatter.string(fromBytes: selected),
                        captionText: "/ \(ByteFormatter.string(fromBytes: reclaimable))",
                        tint: InkPalette.cleanAccent,
                        diameter: 88,
                        lineWidth: 8
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text("已选中 \(Int(fraction * 100))%")
                            .font(.subheadline.weight(.semibold))
                        Text(viewModel.scanIssues.isEmpty ? "\(viewModel.displayGroups.count) 个分类可清理" : "有 \(viewModel.scanIssues.count) 个区域未完整扫描")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if viewModel.isScanning {
                    ProgressView().controlSize(.large)
                    Text("正在扫描…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("尚未扫描 · 点击“开始扫描”查看可清理内容")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                strongModeToggle
            }
        }
        .padding()
    }

    private var strongModeToggle: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Toggle(isOn: Binding(
                get: { viewModel.strongMode },
                set: { on in
                    viewModel.strongMode = on
                    if on { showingStrongModeInfo = true }
                    viewModel.startScan() // re-scan to add/remove deep items
                }
            )) {
                Text("强力模式")
                    .font(.subheadline)
            }
            .toggleStyle(.switch)
            .tint(InkPalette.cleanAccent)
            .disabled(viewModel.isScanning || viewModel.isCleaning)
            Text(viewModel.strongMode ? "更深扫描 · 全部需手动勾选" : "更深/边缘缓存扫描")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .alert("强力模式", isPresented: $showingStrongModeInfo) {
            Button("我知道了") {}
        } message: {
            Text("强力模式会扫描更深、更边缘的缓存（仅限已知安全、可再生成的位置）。为防止误删，扫描到的项目一律不预先勾选，需要你逐项确认；受保护路径在任何模式下都不会被清理，删除仍然先移到废纸篓，可以恢复。")
        }
    }

    private func summaryMessage(_ summary: CleanupSummary) -> String {
        let sizeVerb = summary.dryRun ? "预计可释放" : "释放"
        let countVerb = summary.dryRun ? "将清理" : "清理"
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
    CleanView(viewModel: CleanViewModel())
}

/// Adapts a `ClassifiedItem` to `ConfirmSheetShell`'s itemized-list
/// requirement. Selected items are already filtered to non-protected ones
/// by the time they reach the confirm sheet, so no risk badge is needed here.
private struct CleanConfirmItem: ConfirmSheetItem {
    let classified: ClassifiedItem
    var id: String { classified.id }
    var displayName: String { classified.displayName }
    var sizeText: String? { classified.item.sizeBytes.map(ByteFormatter.string(fromBytes:)) }
    var riskBadge: CategoryRowRisk? { nil }
}
