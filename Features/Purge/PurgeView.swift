import JingshanCore
import SwiftUI

struct PurgeView: View {
    @State private var viewModel = PurgeViewModel()
    @State private var showingConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if viewModel.candidates.isEmpty {
                ContentUnavailableView(
                    viewModel.isScanning ? "正在扫描…" : "还没有扫描结果",
                    systemImage: "archivebox",
                    description: Text(
                        viewModel.isScanning
                            ? "首次扫描可能需要一些时间。"
                            : "点击“开始扫描”查找项目里的构建产物（node_modules、target、.build 等）。扫描目录：\(viewModel.scanRoots.isEmpty ? "未配置，且默认目录不存在" : viewModel.scanRoots.joined(separator: "、"))"
                    )
                )
            } else {
                List(viewModel.candidates) { candidate in
                    PurgeItemRow(candidate: candidate, viewModel: viewModel)
                }
            }
        }
        .navigationTitle("构建产物")
        .sheet(isPresented: $showingConfirmation) {
            CleanConfirmationSheet(
                selectedCount: viewModel.selectedCandidates.count,
                totalBytes: viewModel.totalSelectedBytes,
                onConfirm: { permanently in
                    showingConfirmation = false
                    Task { await viewModel.performCleanup(permanently: permanently) }
                },
                onCancel: { showingConfirmation = false }
            )
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

    @ViewBuilder
    private var header: some View {
        let reclaimable = viewModel.totalReclaimableBytes
        let selected = viewModel.totalSelectedBytes
        let fraction = reclaimable > 0 ? Double(selected) / Double(reclaimable) : 0

        HStack(spacing: 20) {
            if viewModel.hasScannedOnce {
                ArcGauge(
                    valueText: ByteFormatter.string(fromBytes: selected),
                    captionText: "/ \(ByteFormatter.string(fromBytes: reclaimable))",
                    fraction: fraction,
                    tint: SidebarItem.purge.tint
                )
            } else {
                ArcGaugePlaceholder()
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("构建产物").font(.system(size: 16, weight: .bold))
                if viewModel.hasScannedOnce {
                    Text("已选中 \(Int(fraction * 100))% · \(viewModel.candidates.count) 个项目")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("扫描项目目录中的构建产物")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if viewModel.isScanning {
                ProgressView()
                    .controlSize(.small)
                Button("取消") { viewModel.cancelScan() }
            } else {
                Button("开始扫描") { viewModel.startScan() }
                    .disabled(viewModel.isCleaning)
            }
            Button("清理") {
                showingConfirmation = true
            }
            .buttonStyle(.borderedProminent)
            .tint(SidebarItem.purge.tint)
            .disabled(viewModel.selectedCandidates.isEmpty || viewModel.isScanning || viewModel.isCleaning)
        }
        .padding()
        .background(HeroHeaderWash(tint: SidebarItem.purge.tint))
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
    PurgeView()
}
