import AppKit
import JingshanCore
import SwiftUI

struct PurgeView: View {
    let viewModel: PurgeViewModel
    @State private var showingConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .tint(InkPalette.purgeAccent)
        .navigationTitle("构建产物")
        .sheet(isPresented: $showingConfirmation) {
            ConfirmSheetShell(
                title: "确认清理",
                items: viewModel.selectedCandidates.map(PurgeConfirmItem.init),
                totalSizeText: ByteFormatter.string(fromBytes: viewModel.totalSelectedBytes),
                extraAcknowledgment: { _ in EmptyView() },
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

    // Four distinct states, each with its own copy — never a single ambiguous
    // empty view (the old bug: an unconfigured scan flashed the same "no
    // results" state as a completed empty scan).
    @ViewBuilder
    private var content: some View {
        if viewModel.isScanning {
            ScanningStateView(statusText: scanningStatusText)
                .padding(24)
        } else if !viewModel.hasScannedOnce {
            if viewModel.scanRoots.isEmpty {
                EmptyStateView(
                    systemImage: "folder.badge.questionmark",
                    title: "还没有设置扫描目录",
                    message: "选择一个或多个项目目录，净山会在里面查找 node_modules、target、.build 等构建产物。",
                    actionTitle: "选择目录",
                    action: beginScan
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyStateView(
                    systemImage: "archivebox",
                    title: "还没有扫描结果",
                    message: "将扫描：\(viewModel.scanRoots.map(abbreviate).joined(separator: "、"))",
                    actionTitle: "开始扫描",
                    action: beginScan
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if viewModel.candidates.isEmpty {
            EmptyStateView(
                systemImage: "checkmark.circle",
                title: "扫描完成，未发现构建产物",
                message: "扫描目录：\(viewModel.scanRoots.map(abbreviate).joined(separator: "、"))。可在右上「目录…」或设置里调整。",
                actionTitle: "重新扫描",
                action: beginScan
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(viewModel.candidates) { candidate in
                PurgeItemRow(candidate: candidate, viewModel: viewModel)
            }
        }
    }

    private var scanningStatusText: String {
        let where_ = viewModel.scanningPath.map { "正在扫描 \(abbreviate($0))" } ?? "正在扫描…"
        return "\(where_) · 已发现 \(viewModel.liveFoundCount) 项"
    }

    /// The single scan entry point shared by the hero button and the empty-
    /// state button: if no scan roots are set yet, prompt for directories
    /// first (never silently run an empty scan); otherwise scan.
    private func beginScan() {
        if viewModel.scanRoots.isEmpty {
            pickDirectories(thenScan: true)
        } else {
            viewModel.startScan()
        }
    }

    /// Non-sandboxed app with Full Disk Access, so a plain `NSOpenPanel`
    /// selection is directly usable — no security-scoped bookmarks needed.
    private func pickDirectories(thenScan: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "选择"
        panel.message = "选择要扫描构建产物的项目目录（可多选）"
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        for url in panel.urls { AppSettings.shared.addPurgeScanPath(url.path) }
        if thenScan { viewModel.startScan() }
    }

    private func abbreviate(_ path: String) -> String {
        (path as NSString).abbreviatingWithTildeInPath
    }

    @ViewBuilder
    private var header: some View {
        let reclaimable = viewModel.totalReclaimableBytes
        let selected = viewModel.totalSelectedBytes
        let fraction = reclaimable > 0 ? Double(selected) / Double(reclaimable) : 0

        VStack(spacing: 16) {
            HeroHeader(motif: .purge, title: "构建产物", tint: InkPalette.purgeAccent) {
                HStack(spacing: 10) {
                    if viewModel.isScanning {
                        ProgressView().controlSize(.small)
                        Button("取消") { viewModel.cancelScan() }
                    } else {
                        if !viewModel.scanRoots.isEmpty {
                            // Reconfigure scan roots from the page (full
                            // add/remove management also lives in Settings).
                            Button("目录…") { pickDirectories(thenScan: false) }
                                .help("添加扫描目录")
                        }
                        Button(viewModel.scanRoots.isEmpty ? "选择目录" : "开始扫描", action: beginScan)
                            .disabled(viewModel.isCleaning)
                    }
                    Button("清理") {
                        showingConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(InkPalette.purgeAccent)
                    .disabled(viewModel.selectedCandidates.isEmpty || viewModel.isScanning || viewModel.isCleaning)
                }
            }

            HStack(spacing: 20) {
                if viewModel.hasScannedOnce {
                    RingGauge(
                        progress: fraction,
                        valueText: ByteFormatter.string(fromBytes: selected),
                        captionText: "/ \(ByteFormatter.string(fromBytes: reclaimable))",
                        tint: InkPalette.purgeAccent,
                        diameter: 88,
                        lineWidth: 8
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text("已选中 \(Int(fraction * 100))%")
                            .font(.subheadline.weight(.semibold))
                        Text("\(viewModel.candidates.count) 个项目")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    RingGaugePlaceholder(diameter: 88, lineWidth: 8)
                    Text("扫描项目目录中的构建产物")
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
}

#Preview {
    PurgeView(viewModel: PurgeViewModel())
}

private struct PurgeConfirmItem: ConfirmSheetItem {
    let candidate: PurgeCandidate
    var id: String { candidate.id }
    var displayName: String { "\(candidate.projectName) · \(candidate.artifactLabel)" }
    var sizeText: String? { candidate.sizeBytes.map(ByteFormatter.string(fromBytes:)) }
    var riskBadge: CategoryRowRisk? { candidate.isRecent ? .caution : nil }
}
