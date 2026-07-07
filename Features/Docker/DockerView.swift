import AppKit
import JingshanCore
import SwiftUI

struct DockerView: View {
    @State private var viewModel = DockerViewModel()
    @State private var showingConfirmation = false

    var body: some View {
        Group {
            switch viewModel.daemonState {
            case .checking:
                ProgressView("检测 Docker…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .notInstalled where viewModel.hostItems.isEmpty:
                ContentUnavailableView(
                    "未检测到 Docker",
                    systemImage: "shippingbox",
                    description: Text("请先安装 Docker Desktop，然后回到净山。")
                )
            default:
                scanContent
            }
        }
        .navigationTitle("Docker")
        .task {
            if viewModel.daemonState == .checking {
                viewModel.refresh()
            }
        }
        .sheet(isPresented: $showingConfirmation) {
            DockerConfirmationSheet(
                selectedCount: viewModel.selectedItems.count,
                totalBytes: viewModel.totalSelectedBytes,
                hasDestructiveSelection: viewModel.hasDestructiveSelection,
                onConfirm: {
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
                ProgressView("正在扫描…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Docker 未运行")
                        .font(.subheadline.weight(.medium))
                    Text("下面的磁盘数据可以直接清理，无需启动 Docker。要精细清理容器、镜像、构建缓存，请启动 Docker。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if viewModel.daemonState == .daemonNotRunning {
                    if viewModel.isStartingDocker {
                        ProgressView().controlSize(.small)
                    } else {
                        Button("启动 Docker") {
                            Task { await viewModel.startDockerDesktop() }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } else if viewModel.dockerDesktopRunning && viewModel.daemonState == .available {
            // Docker running: host VM-disk reclaim is intentionally withheld.
            Label("虚拟磁盘（整个数据存储）需完全退出 Docker Desktop 后才能回收。", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
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

        HStack(spacing: 20) {
            if viewModel.hasScannedOnce {
                ArcGauge(
                    valueText: ByteFormatter.string(fromBytes: selected),
                    captionText: "/ \(ByteFormatter.string(fromBytes: scanned))",
                    fraction: fraction,
                    tint: SidebarItem.docker.tint
                )
            } else {
                ArcGaugePlaceholder()
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Docker").font(.system(size: 16, weight: .bold))
                if viewModel.hasScannedOnce {
                    Text("已选中 \(Int(fraction * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("扫描 Docker 磁盘数据与运行时资源")
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
                Button("重新扫描") { viewModel.refresh() }
                    .disabled(viewModel.isCleaning)
            }
            Button("清理") {
                showingConfirmation = true
            }
            .buttonStyle(.borderedProminent)
            .tint(SidebarItem.docker.tint)
            .disabled(viewModel.selectedItems.isEmpty || viewModel.isScanning || viewModel.isCleaning)
        }
        .background(HeroHeaderWash(tint: SidebarItem.docker.tint))
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
    DockerView()
}
