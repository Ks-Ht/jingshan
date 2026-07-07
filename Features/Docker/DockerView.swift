import AppKit
import JingshanCore
import SwiftUI

struct DockerView: View {
    let viewModel: DockerViewModel
    @State private var showingConfirmation = false
    @State private var acknowledgedDestructive = false

    var body: some View {
        Group {
            switch viewModel.daemonState {
            case .checking:
                ProgressView("检测 Docker…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .notInstalled where viewModel.hostItems.isEmpty:
                EmptyStateView(
                    systemImage: "shippingbox",
                    title: "未检测到 Docker",
                    message: "请先安装 Docker Desktop，然后回到净山。"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            default:
                scanContent
            }
        }
        .navigationTitle("Docker")
        .tint(InkPalette.dockerAccent)
        .task {
            if viewModel.daemonState == .checking {
                viewModel.refresh()
            }
        }
        .sheet(isPresented: $showingConfirmation) {
            ConfirmSheetShell(
                title: "确认清理 Docker 资源",
                items: viewModel.selectedItems.map(DockerConfirmItem.init),
                totalSizeText: ByteFormatter.string(fromBytes: viewModel.totalSelectedBytes),
                permanentDeleteToggle: false,
                extraAcknowledgment: { _ in
                    DockerDestructiveAcknowledgment(
                        hasDestructiveSelection: viewModel.hasDestructiveSelection,
                        acknowledged: $acknowledgedDestructive
                    )
                },
                extraAcknowledgmentSatisfied: { _ in !viewModel.hasDestructiveSelection || acknowledgedDestructive },
                onConfirm: { _ in
                    showingConfirmation = false
                    Task { await viewModel.performCleanup() }
                },
                onCancel: { showingConfirmation = false }
            )
        }
        .alert(
            viewModel.lastCleanupSummary?.dryRun == true ? "预览结果（未实际清理）" : "清理完成",
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
            if viewModel.isScanning && viewModel.hostItems.isEmpty && viewModel.runtimeItems.isEmpty {
                ScanningStateView(statusText: "正在扫描 Docker 磁盘数据与运行时资源…")
                    .padding(24)
            } else {
                List {
                    daemonBanner
                    hostSection
                    runtimeSection
                    if viewModel.hostItems.isEmpty && viewModel.runtimeItems.isEmpty && !viewModel.isScanning {
                        Text("目前没有可清理的 Docker 数据。")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // Explains the current daemon state and offers to start Docker when the
    // granular (runtime) cleanup needs it.
    @ViewBuilder
    private var daemonBanner: some View {
        if viewModel.daemonState == .daemonNotRunning || viewModel.daemonState == .notInstalled {
            InfoBanner(
                systemImage: "info.circle",
                message: "Docker 未运行 — 下面的磁盘数据可以直接清理，无需启动 Docker。要精细清理容器、镜像、构建缓存，请启动 Docker。",
                tint: InkPalette.dockerAccent,
                actionTitle: viewModel.daemonState == .daemonNotRunning ? "启动 Docker" : nil,
                action: { Task { await viewModel.startDockerDesktop() } },
                isLoading: viewModel.isStartingDocker
            )
            .padding(.vertical, 4)
        } else if viewModel.dockerDesktopRunning && viewModel.daemonState == .available {
            // Docker running: host VM-disk reclaim is intentionally withheld.
            InfoBanner(
                systemImage: "info.circle",
                message: "虚拟磁盘（整个数据存储）需完全退出 Docker Desktop 后才能回收。",
                tint: InkPalette.dockerAccent
            )
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var hostSection: some View {
        if !viewModel.hostItems.isEmpty {
            Section {
                ForEach(viewModel.hostItemsByKind, id: \.kind) { entry in
                    ForEach(entry.items) { item in
                        DockerItemRow(item: item, viewModel: viewModel)
                    }
                }
            } header: {
                sectionHeader("磁盘数据", subtitle: "Docker 在硬盘上占用的数据，Docker 停止时也能清理", total: viewModel.hostTotalBytes)
            }
        }
    }

    @ViewBuilder
    private var runtimeSection: some View {
        if !viewModel.runtimeItems.isEmpty {
            ForEach(viewModel.runtimeItemsByKind, id: \.kind) { entry in
                Section {
                    ForEach(entry.items) { item in
                        DockerItemRow(item: item, viewModel: viewModel)
                    }
                } header: {
                    Label(entry.kind.displayName, systemImage: entry.kind.systemImage)
                }
            }
        }
    }

    private func sectionHeader(_ title: String, subtitle: String, total: Int64) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text(ByteFormatter.string(fromBytes: total)).foregroundStyle(.secondary)
            }
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var header: some View {
        let scanned = viewModel.hostTotalBytes + viewModel.runtimeTotalBytes
        let selected = viewModel.totalSelectedBytes
        let fraction = scanned > 0 ? Double(selected) / Double(scanned) : 0

        VStack(spacing: 16) {
            HeroHeader(motif: .docker, title: "Docker", tint: InkPalette.dockerAccent) {
                HStack(spacing: 10) {
                    if viewModel.isScanning {
                        ProgressView().controlSize(.small)
                        Button("取消") { viewModel.cancelScan() }
                    } else {
                        Button("重新扫描") { viewModel.refresh() }
                            .disabled(viewModel.isCleaning)
                    }
                    Button("清理") {
                        acknowledgedDestructive = false // fresh acknowledgment required for every new confirm-sheet presentation
                        showingConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(InkPalette.dockerAccent)
                    .disabled(viewModel.selectedItems.isEmpty || viewModel.isScanning || viewModel.isCleaning)
                }
            }

            HStack(spacing: 20) {
                if viewModel.hasScannedOnce {
                    RingGauge(
                        progress: fraction,
                        valueText: ByteFormatter.string(fromBytes: selected),
                        captionText: "/ \(ByteFormatter.string(fromBytes: scanned))",
                        tint: InkPalette.dockerAccent,
                        diameter: 88,
                        lineWidth: 8
                    )
                    Text("已选中 \(Int(fraction * 100))%")
                        .font(.subheadline.weight(.semibold))
                } else {
                    RingGaugePlaceholder(diameter: 88, lineWidth: 8)
                    Text("扫描 Docker 磁盘数据与运行时资源")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding()
    }

    private func summaryMessage(_ summary: DockerCleanupSummary) -> String {
        let sizeVerb = summary.dryRun ? "预计可释放" : "释放"
        let countVerb = summary.dryRun ? "将清理" : "清理"
        var parts = ["\(sizeVerb) \(ByteFormatter.string(fromBytes: summary.freedBytes))", "\(countVerb) \(summary.removedCount) 项"]
        if summary.failedCount > 0 {
            parts.append("失败 \(summary.failedCount) 项")
        }
        return parts.joined(separator: "，")
    }
}

#Preview {
    DockerView(viewModel: DockerViewModel())
}

private struct DockerConfirmItem: ConfirmSheetItem {
    let item: DockerCleanableItem
    var id: String { item.id }
    var displayName: String { item.displayName }
    var sizeText: String? { item.sizeBytes.map(ByteFormatter.string(fromBytes:)) }
    var riskBadge: CategoryRowRisk? { item.risk.categoryRowRisk }
}

/// Docker's destructive-tier gate: same copy and behavior as the old
/// `DockerConfirmationSheet`'s inline branch, just relocated so
/// `ConfirmSheetShell` can inject it via `extraAcknowledgment`.
private struct DockerDestructiveAcknowledgment: View {
    let hasDestructiveSelection: Bool
    @Binding var acknowledged: Bool

    var body: some View {
        if hasDestructiveSelection {
            VStack(alignment: .leading, spacing: 8) {
                Label("包含高风险项（正在运行的容器或数据卷），删除后数据无法恢复。", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(RiskTint.irreversible)
                    .font(.callout)
                Toggle("我了解这会永久删除数据，且无法撤销", isOn: $acknowledged)
            }
        } else {
            Text("以上操作都可以通过重新拉取镜像或重建容器恢复，不涉及不可逆的数据丢失。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
