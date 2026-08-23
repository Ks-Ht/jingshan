import JingshanCore
import SwiftUI

/// The landing tab: a health-check hero (score ring + one-tap check + primary
/// actions), a row of six module tiles that jump to their tab, and a live
/// system-overview card. Reads the module view models (owned by `RootView`)
/// directly so its numbers reflect each module's latest scan.
struct HomeView: View {
    let cleanVM: CleanViewModel
    let dockerVM: DockerViewModel
    let purgeVM: PurgeViewModel
    let uninstallVM: UninstallerViewModel
    let largeFilesVM: LargeFilesViewModel
    let statusVM: StatusViewModel

    let lastCheckDate: Date?
    let onOpen: (AppTab) -> Void
    let onHealthCheck: () -> Void

    @State private var history = CleanupHistoryStore.shared
    @State private var showingHistory = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HealthCheckHeroCard(
                    hasSampled: statusVM.hasSampledOnce,
                    healthScore: statusVM.healthScorePercent,
                    worstUsage: statusVM.worstUsagePercent,
                    cleanableBytes: cleanableBytes,
                    hasCleanScan: cleanVM.hasScannedOnce || purgeVM.hasScannedOnce || largeFilesVM.hasScannedOnce,
                    lastCheckDate: lastCheckDate,
                    isChecking: isChecking,
                    onHealthCheck: onHealthCheck,
                    onClean: { onOpen(.clean) }
                )

                HStack(spacing: 10) {
                    ModuleTile(tab: .clean, name: "清理", value: cleanValue, onOpen: onOpen)
                    ModuleTile(tab: .docker, name: "Docker", value: dockerValue, onOpen: onOpen)
                    ModuleTile(tab: .purge, name: "构建产物", value: purgeValue, onOpen: onOpen)
                    ModuleTile(tab: .uninstall, name: "卸载应用", value: uninstallValue, onOpen: onOpen)
                    ModuleTile(tab: .largeFiles, name: "大文件", value: largeFilesValue, onOpen: onOpen)
                    ModuleTile(tab: .status, name: "状态", value: statusValue, onOpen: onOpen)
                }

                SystemOverviewCard(
                    cpu: statusVM.hasSampledOnce ? statusVM.snapshot.cpu.totalUsagePercent : nil,
                    memory: statusVM.hasSampledOnce ? statusVM.snapshot.memory.usedPercent : nil,
                    disk: statusVM.hasSampledOnce ? statusVM.snapshot.disk.usedPercent : nil
                )

                CumulativeHistoryCard(
                    totalBytes: history.totalFreedBytes,
                    count: history.totalCleanupCount,
                    onOpenHistory: { showingHistory = true }
                )
            }
            .padding(16)
        }
        .tint(InkPalette.accent) // green brand accent for all controls (e.g. "前往清理"), not system blue
        .sheet(isPresented: $showingHistory) {
            CleanupHistoryView(onClose: { showingHistory = false })
        }
    }

    private var cleanableBytes: Int64 {
        cleanVM.totalReclaimableBytes + purgeVM.totalReclaimableBytes + largeFilesVM.totalBytes
    }

    private var isChecking: Bool {
        cleanVM.isScanning || dockerVM.isScanning || purgeVM.isScanning || uninstallVM.isScanningApps || largeFilesVM.isScanning
    }

    private var cleanValue: TileValue {
        cleanVM.hasScannedOnce ? .data(ByteFormatter.string(fromBytes: cleanVM.totalReclaimableBytes)) : .pending
    }
    private var dockerValue: TileValue {
        dockerVM.hasScannedOnce ? .data(ByteFormatter.string(fromBytes: dockerVM.hostTotalBytes + dockerVM.runtimeTotalBytes)) : .pending
    }
    private var purgeValue: TileValue {
        purgeVM.hasScannedOnce ? .data(ByteFormatter.string(fromBytes: purgeVM.totalReclaimableBytes)) : .pending
    }
    private var uninstallValue: TileValue {
        uninstallVM.installedApps.isEmpty
            ? (uninstallVM.isScanningApps ? .data("扫描中") : .pending)
            : .data("\(uninstallVM.installedApps.count) 个")
    }
    private var largeFilesValue: TileValue {
        largeFilesVM.hasScannedOnce ? .data(ByteFormatter.string(fromBytes: largeFilesVM.totalBytes)) : .pending
    }
    private var statusValue: TileValue {
        statusVM.hasSampledOnce ? .data("\(Int(statusVM.worstUsagePercent.rounded()))%") : .placeholder
    }
}

// MARK: - Health-check hero

private struct HealthCheckHeroCard: View {
    // Value-driven (not VM-driven) so it renders identically from live state
    // or from fixed sample values in the offscreen snapshot harness.
    let hasSampled: Bool
    let healthScore: Double
    let worstUsage: Double
    let cleanableBytes: Int64
    let hasCleanScan: Bool
    let lastCheckDate: Date?
    let isChecking: Bool
    let onHealthCheck: () -> Void
    let onClean: () -> Void

    var body: some View {
        HStack(spacing: 22) {
            ring
            VStack(alignment: .leading, spacing: 6) {
                Text(titleText)
                    .font(.system(size: 20, weight: .bold))
                subtitle
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            VStack(spacing: 8) {
                Button(action: onHealthCheck) {
                    HStack(spacing: 6) {
                        if isChecking { ProgressView().controlSize(.small) }
                        Text(isChecking ? "体检中…" : "一键体检")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(InkPalette.accent)
                .disabled(isChecking)

                // "前往清理" (not "立即清理") — this only navigates to the
                // Clean page for manual selection; it must never read as an
                // immediate one-click delete. The frame lives INSIDE the label
                // so the button chrome stretches to match "一键体检" above.
                Button { onClean() } label: {
                    Text("前往清理").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .frame(width: 130)
        }
        .heroWashCard()
    }

    @ViewBuilder private var ring: some View {
        if hasSampled {
            RingGauge(
                progress: healthScore / 100,
                valueText: "\(Int(healthScore.rounded()))",
                captionText: "健康分",
                tint: SystemHealthTint.forUsagePercent(worstUsage),
                diameter: 96,
                lineWidth: 9
            )
        } else {
            RingGaugePlaceholder(diameter: 96, lineWidth: 9)
        }
    }

    private var titleText: String {
        guard hasSampled else { return "正在检测系统…" }
        if healthScore >= 80 { return "系统运行良好" }
        if healthScore >= 60 { return "系统状态尚可" }
        return "建议清理优化"
    }

    private var subtitle: Text {
        guard hasCleanScan else {
            return Text("点击「一键体检」查看可清理空间")
        }
        var text = Text("扫描到 ")
            + Text(ByteFormatter.string(fromBytes: cleanableBytes))
                .foregroundStyle(InkPalette.accent)
                .fontWeight(.semibold)
            + Text(" 可清理空间")
        if let lastCheckDate {
            // `Text(date, style: .relative)` renders an English-style
            // "2 hr, 0 min" here; format Chinese "2小时前" explicitly instead.
            text = text + Text(" · 上次体检 \(Self.relativeString(from: lastCheckDate))")
        }
        return text
    }

    /// Recomputed each render (the home view re-renders ~1×/s while sampling),
    /// so it stays current without needing `Text`'s auto-updating relative style.
    private static func relativeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_Hans")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Module tiles

private enum TileValue {
    case data(String)
    case pending
    case placeholder
}

private struct ModuleTile: View {
    let tab: AppTab
    let name: String
    let value: TileValue
    let onOpen: (AppTab) -> Void

    @State private var isHovering = false

    var body: some View {
        Button { onOpen(tab) } label: {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tab.tint)
                    .frame(width: 36, height: 36)
                    .background(tab.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(tab.tint.opacity(0.18), lineWidth: 0.5)
                    )
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                valueText
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .homeCard()
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tab.tint.opacity(isHovering ? 0.35 : 0), lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
        .hoverLift()
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .combine)
    }

    // Main datum: 17.5px rounded semibold, monospaced digits.
    @ViewBuilder private var valueText: some View {
        switch value {
        case .data(let string):
            Text(string)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
        case .pending:
            Text("待扫描")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.tertiary)
        case .placeholder:
            Text("--")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - System overview

private struct SystemOverviewCard: View {
    let cpu: Double?
    let memory: Double?
    let disk: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("系统概览")
                .font(.headline)
            HStack(alignment: .top, spacing: 16) {
                OverviewCell(label: "CPU", percent: cpu, base: InkPalette.accent)
                OverviewCell(label: "内存", percent: memory, base: InkPalette.accent)
                OverviewCell(label: "磁盘", percent: disk, base: InkPalette.coolCyan)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard()
    }
}

private struct OverviewCell: View {
    let label: String
    let percent: Double?
    let base: Color

    private var tint: Color {
        guard let percent else { return .secondary }
        if percent >= 90 { return RiskTint.destructive }
        if percent >= 70 { return RiskTint.caution }
        return base
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text(percent.map { "\(Int($0.rounded()))%" } ?? "--")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(tint)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.07))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat((percent ?? 0) / 100))))
                }
            }
            .frame(height: 7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(percent.map { "\(Int($0.rounded()))%" } ?? "暂无数据")")
    }
}

// MARK: - Cumulative cleanup history (A1)

private struct CumulativeHistoryCard: View {
    let totalBytes: Int64
    let count: Int
    let onOpenHistory: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(InkPalette.accent)
                .frame(width: 36, height: 36)
                .background(InkPalette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(InkPalette.accent.opacity(0.18), lineWidth: 0.5)
                )
            VStack(alignment: .leading, spacing: 2) {
                (Text("累计已释放 ")
                    + Text(ByteFormatter.string(fromBytes: totalBytes))
                        .foregroundStyle(InkPalette.accent).fontWeight(.semibold)
                    + Text(" · 共 \(count) 次清理"))
                    .font(.subheadline)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("每次清理都可从废纸篓一键恢复 · 记录仅保存在本机")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Button("清理历史") { onOpenHistory() }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard()
    }
}

// MARK: - Shared card chrome

private extension View {
    /// Home cards ride the app-wide elevated-card chrome.
    func homeCard() -> some View {
        inkCard()
    }

    /// The health-check hero's signature chrome: the shared card surface with
    /// a brand-green wash draining from the top-left and its own faint
    /// mountain silhouette on the floor.
    func heroWashCard() -> some View {
        self
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .bottom) {
                MountainSilhouette(tint: InkPalette.accent, height: 52)
            }
            .background(
                LinearGradient(
                    colors: [InkPalette.accent.opacity(0.12), InkPalette.accent.opacity(0.02)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .background(InkPalette.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(InkPalette.accent.opacity(0.18), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
            .shadow(color: .black.opacity(0.05), radius: 14, y: 6)
    }
}

#if DEBUG
struct HomeSnapshotContent: View {
    var body: some View {
        VStack(spacing: 16) {
            HealthCheckHeroCard(
                hasSampled: true, healthScore: 88, worstUsage: 26,
                cleanableBytes: 12_300_000_000, hasCleanScan: true,
                lastCheckDate: Date().addingTimeInterval(-7200), isChecking: false,
                onHealthCheck: {}, onClean: {}
            )
            HStack(spacing: 10) {
                ModuleTile(tab: .clean, name: "清理", value: .data("12.3 GB"), onOpen: { _ in })
                ModuleTile(tab: .docker, name: "Docker", value: .data("1.9 GB"), onOpen: { _ in })
                ModuleTile(tab: .purge, name: "构建产物", value: .pending, onOpen: { _ in })
                ModuleTile(tab: .uninstall, name: "卸载应用", value: .data("48 个"), onOpen: { _ in })
                ModuleTile(tab: .largeFiles, name: "大文件", value: .data("3.2 GB"), onOpen: { _ in })
                ModuleTile(tab: .status, name: "状态", value: .data("26%"), onOpen: { _ in })
            }
            SystemOverviewCard(cpu: 26, memory: 73, disk: 52)
            CumulativeHistoryCard(totalBytes: 48_600_000_000, count: 12, onOpenHistory: {})
        }
        .padding(16)
        .background(InkPalette.paper)
    }
}
#endif
