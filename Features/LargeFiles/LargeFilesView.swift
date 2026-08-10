import AppKit
import JingshanCore
import SwiftUI

struct LargeFilesView: View {
    let viewModel: LargeFilesViewModel
    @State private var showingConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .tint(InkPalette.coolCyan)
        .navigationTitle("大文件")
        .sheet(isPresented: $showingConfirmation) {
            ConfirmSheetShell(
                title: "确认清理大文件",
                items: viewModel.selectedCandidates.map(LargeFileConfirmItem.init),
                totalSizeText: ByteFormatter.string(fromBytes: viewModel.totalSelectedBytes),
                extraAcknowledgment: { _ in
                    Label("这些是你自己的文件（不是缓存），删除前请再确认一遍。默认移入废纸篓，可从「清理历史」一键恢复。", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(RiskTint.caution)
                },
                tint: InkPalette.coolCyan,
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

    @ViewBuilder
    private var content: some View {
        if viewModel.isScanning {
            ScanningStateView(statusText: scanningStatusText)
                .padding(24)
        } else if !viewModel.hasScannedOnce {
            EmptyStateView(
                systemImage: "doc.viewfinder",
                title: "查找大文件",
                message: "扫描 \(abbreviate(viewModel.scanRoot)) 里超过 100 MB 的文件，并标出很久没打开过的旧文件。",
                actionTitle: "开始扫描",
                action: { viewModel.startScan() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.candidates.isEmpty {
            EmptyStateView(
                systemImage: "checkmark.circle",
                title: "没有找到大文件",
                message: "在 \(abbreviate(viewModel.scanRoot)) 里没有超过 100 MB 的文件。"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(viewModel.candidates) { candidate in
                CategoryRow(
                    title: candidate.displayName,
                    subtitle: candidate.path,
                    risk: .caution,
                    riskNote: rowNote(candidate),
                    sizeText: ByteFormatter.string(fromBytes: candidate.sizeBytes),
                    isSelected: viewModel.isSelected(candidate),
                    tint: InkPalette.coolCyan,
                    onToggle: { viewModel.setSelected(candidate, $0) }
                )
            }
        }
    }

    private func rowNote(_ candidate: LargeFileScanner.Candidate) -> String {
        var parts: [String] = []
        if let access = candidate.lastAccessDate {
            parts.append("最近打开 \(Self.dateFormatter.string(from: access))")
        }
        if candidate.isOld { parts.append("很久未使用") }
        parts.append("这是你自己的文件")
        return parts.joined(separator: " · ")
    }

    private var scanningStatusText: String {
        let path = viewModel.scanningPath.map(abbreviate) ?? "…"
        return "正在扫描 \(path) · 已发现 \(viewModel.liveFoundCount) 个大文件"
    }

    @ViewBuilder
    private var header: some View {
        VStack(spacing: 16) {
            HeroHeader(motif: .largeFiles, title: "大文件", tint: InkPalette.coolCyan) {
                HStack(spacing: 10) {
                    if viewModel.isScanning {
                        ProgressView().controlSize(.small)
                        Button("取消") { viewModel.cancelScan() }
                    } else {
                        Button("选择目录…") { pickDirectory() }
                        Button("扫描") { viewModel.startScan() }
                            .disabled(viewModel.isCleaning)
                    }
                    Button("清理") { showingConfirmation = true }
                        .buttonStyle(.borderedProminent)
                        .tint(InkPalette.coolCyan)
                        .disabled(viewModel.selectedCandidates.isEmpty || viewModel.isScanning || viewModel.isCleaning)
                }
            }

            HStack(spacing: 20) {
                if viewModel.hasScannedOnce {
                    RingGauge(
                        progress: viewModel.totalBytes > 0 ? Double(viewModel.totalSelectedBytes) / Double(viewModel.totalBytes) : 0,
                        valueText: ByteFormatter.string(fromBytes: viewModel.totalSelectedBytes),
                        captionText: "/ \(ByteFormatter.string(fromBytes: viewModel.totalBytes))",
                        tint: InkPalette.coolCyan,
                        diameter: 88,
                        lineWidth: 8
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(viewModel.candidates.count) 个大文件")
                            .font(.subheadline.weight(.semibold))
                        Text("其中 \(viewModel.oldCount) 个很久未使用")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if viewModel.isScanning {
                    ProgressView().controlSize(.large)
                    Text("正在扫描大文件…").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("扫描目录：\(abbreviate(viewModel.scanRoot))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding()
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        panel.message = "选择要查找大文件的目录"
        panel.directoryURL = URL(fileURLWithPath: viewModel.scanRoot)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        viewModel.scanRoot = url.path
        viewModel.startScan()
    }

    private func abbreviate(_ path: String) -> String {
        (path as NSString).abbreviatingWithTildeInPath
    }

    private func summaryMessage(_ summary: CleanupSummary) -> String {
        let sizeVerb = summary.dryRun ? "预计可释放" : "释放"
        let countVerb = summary.dryRun ? "将清理" : "清理"
        var parts = ["\(sizeVerb) \(ByteFormatter.string(fromBytes: summary.freedBytes))", "\(countVerb) \(summary.deletedCount) 项"]
        if summary.failedCount > 0 { parts.append("失败 \(summary.failedCount) 项") }
        return parts.joined(separator: "，")
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hans")
        f.dateFormat = "yyyy年M月"
        return f
    }()
}

private struct LargeFileConfirmItem: ConfirmSheetItem {
    let candidate: LargeFileScanner.Candidate
    var id: String { candidate.id }
    var displayName: String { candidate.displayName }
    var sizeText: String? { ByteFormatter.string(fromBytes: candidate.sizeBytes) }
    var riskBadge: CategoryRowRisk? { .caution }
}
