import AppKit
import JingshanCore
import SwiftUI

struct CleanView: View {
    let viewModel: CleanViewModel
    @State private var hasFullDiskAccess = FullDiskAccessChecker.hasFullDiskAccess()
    @State private var showingConfirmation = false
    @State private var showingEmptyTrashConfirmation = false

    var body: some View {
        Group {
            if hasFullDiskAccess {
                scanContent
            } else {
                PermissionOnboardingView(onOpenSettings: openPrivacySettings)
            }
        }
        .navigationTitle("清理")
        .tint(InkPalette.cleanAccent) // module color for all controls here, not system blue
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasFullDiskAccess = FullDiskAccessChecker.hasFullDiskAccess()
        }
        .sheet(isPresented: $showingConfirmation) {
            ConfirmSheetShell(
                title: "确认清理",
                items: confirmItems,
                totalSizeText: ByteFormatter.string(fromBytes: viewModel.totalSelectedBytes),
                extraAcknowledgment: { _ in EmptyView() },
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
            if viewModel.categories.isEmpty {
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
            } else {
                List {
                    ForEach(viewModel.displayGroups) { group in
                        CleanGroupSectionView(group: group, viewModel: viewModel)
                    }
                    if let trash = viewModel.trashCategory, let item = trash.items.first {
                        trashRow(item)
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
            Button("清空废纸篓") {
                showingEmptyTrashConfirmation = true
            }
            .disabled(viewModel.isCleaning || (item.sizeBytes ?? 0) == 0)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var header: some View {
        let reclaimable = viewModel.totalReclaimableBytes
        let selected = viewModel.totalSelectedBytes
        let fraction = reclaimable > 0 ? Double(selected) / Double(reclaimable) : 0

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
                    Button("清理") {
                        showingConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(InkPalette.cleanAccent)
                    .disabled(viewModel.selectedItems.isEmpty || viewModel.isScanning || viewModel.isCleaning)
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
                        Text("\(viewModel.displayGroups.count) 个分类可清理")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    RingGaugePlaceholder(diameter: 88, lineWidth: 8)
                    Text("尚未扫描 · 点击“开始扫描”查看可清理内容")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding()
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

    private func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else { return }
        NSWorkspace.shared.open(url)
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
