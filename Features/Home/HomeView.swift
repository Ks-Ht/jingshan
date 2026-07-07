import JingshanCore
import SwiftUI

/// The landing tab: a health-check hero (score ring + one-tap check + primary
/// actions), a row of five module tiles that jump to their tab, and a live
/// system-overview card. Reads the five module view models (owned by
/// `RootView`) directly so its numbers reflect each module's latest scan.
struct HomeView: View {
    let cleanVM: CleanViewModel
    let dockerVM: DockerViewModel
    let purgeVM: PurgeViewModel
    let uninstallVM: UninstallerViewModel
    let statusVM: StatusViewModel

    let lastCheckDate: Date?
    let onOpen: (AppTab) -> Void
    let onHealthCheck: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HealthCheckHeroCard(
                    hasSampled: statusVM.hasSampledOnce,
                    healthScore: statusVM.healthScorePercent,
                    worstUsage: statusVM.worstUsagePercent,
                    cleanableBytes: cleanableBytes,
                    hasCleanScan: cleanVM.hasScannedOnce || purgeVM.hasScannedOnce,
                    lastCheckDate: lastCheckDate,
                    isChecking: isChecking,
                    onHealthCheck: onHealthCheck,
                    onClean: { onOpen(.clean) }
                )

                HStack(spacing: 12) {
                    ModuleTile(tab: .clean, name: "清理", value: cleanValue, onOpen: onOpen)
                    ModuleTile(tab: .docker, name: "Docker", value: dockerValue, onOpen: onOpen)
                    ModuleTile(tab: .purge, name: "构建产物", value: purgeValue, onOpen: onOpen)
                    ModuleTile(tab: .uninstall, name: "卸载应用", value: uninstallValue, onOpen: onOpen)
                    ModuleTile(tab: .status, name: "状态", value: statusValue, onOpen: onOpen)
                }

                SystemOverviewCard(
                    cpu: statusVM.hasSampledOnce ? statusVM.snapshot.cpu.totalUsagePercent : nil,
                    memory: statusVM.hasSampledOnce ? statusVM.snapshot.memory.usedPercent : nil,
                    disk: statusVM.hasSampledOnce ? statusVM.snapshot.disk.usedPercent : nil
                )
            }
            .padding(16)
        }
        .tint(InkPalette.accent) // green brand accent for all controls (e.g. "前往清理"), not system blue
        // Sampling is started/stopped by RootView based on the active tab, not
        // here — Home and Status share one `statusVM`, and toggling it from
        // both views' appear/disappear races during a cross-fade tab switch.
    }

    private var cleanableBytes: Int64 {
        cleanVM.totalReclaimableBytes + purgeVM.totalReclaimableBytes
    }

    private var isChecking: Bool {
        cleanVM.isScanning || dockerVM.isScanning || purgeVM.isScanning || uninstallVM.isScanningApps
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
                    .font(.title3.bold())
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
                // immediate one-click delete.
                Button("前往清理") { onClean() }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
            }
            .frame(width: 130)
        }
        .homeCard()
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
                .foregroundColor(InkPalette.accent)
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
            // Fixed vertical rhythm (icon → 8 → name → 4 → value), top-aligned,
            // and stretched to `maxHeight: .infinity` so all five tiles in the
            // row share the tallest one's height (equal-height, bottom edges
            // aligned) instead of each sizing to its own content.
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tab.tint)
                    .frame(width: 34, height: 34)
                    .background(tab.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))
                Text(name)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                valueText
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .homeCard()
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tab.tint.opacity(isHovering ? 0.4 : 0), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .combine)
    }

    // Main datum: 17px / medium / monospaced. Real values take the primary ink;
    // the "待扫描"/"--" empty states are muted so they read as placeholders.
    @ViewBuilder private var valueText: some View {
        switch value {
        case .data(let string):
            Text(string)
                .font(.system(size: 17, weight: .medium))
                .monospacedDigit()
                .contentTransition(.numericText())
        case .pending:
            Text("待扫描")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.tertiary)
        case .placeholder:
            Text("--")
                .font(.system(size: 17, weight: .medium))
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
            Text("系统概览").font(.headline)
            // Even three-column grid: each cell carries its own label + right-
            // aligned percent above a full-cell-width bar, so the three bars are
            // equal length and evenly spaced (the old single row let the bars run
            // long and bunched unevenly).
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

    /// Escalates the base "healthy" tint to amber (70–90%) / vermilion (≥90%).
    private var tint: Color {
        guard let percent else { return .secondary }
        if percent >= 90 { return InkPalette.vermilion }
        if percent >= 70 { return InkPalette.amber }
        return base
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption)
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
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(tint)
                        .frame(width: geo.size.width * CGFloat((percent ?? 0) / 100))
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(percent.map { "\(Int($0.rounded()))%" } ?? "暂无数据")")
    }
}

// MARK: - Shared card chrome

private extension View {
    func homeCard() -> some View {
        self
            .padding(16)
            // Shadow lives on the background shape so it renders outside the
            // card rather than being clipped by it.
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(InkPalette.card)
                    .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
            )
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(InkPalette.hairline, lineWidth: 0.5))
    }
}

#if DEBUG
/// A fully-populated home layout with fixed sample values matching the
/// reference design — for the offscreen `ImageRenderer` snapshot harness
/// (`SnapshotHarness`), which lets us actually see the rendered SwiftUI
/// without any screen-recording permission. Lives here so it can reach the
/// file-private section components; internal so the harness (App target) can
/// render it.
struct HomeSnapshotContent: View {
    var body: some View {
        VStack(spacing: 16) {
            HealthCheckHeroCard(
                hasSampled: true, healthScore: 88, worstUsage: 26,
                cleanableBytes: 12_300_000_000, hasCleanScan: true,
                lastCheckDate: Date().addingTimeInterval(-7200), isChecking: false,
                onHealthCheck: {}, onClean: {}
            )
            HStack(spacing: 12) {
                ModuleTile(tab: .clean, name: "清理", value: .data("12.3 GB"), onOpen: { _ in })
                ModuleTile(tab: .docker, name: "Docker", value: .data("1.9 GB"), onOpen: { _ in })
                ModuleTile(tab: .purge, name: "构建产物", value: .pending, onOpen: { _ in })
                ModuleTile(tab: .uninstall, name: "卸载应用", value: .data("48 个"), onOpen: { _ in })
                ModuleTile(tab: .status, name: "状态", value: .data("26%"), onOpen: { _ in })
            }
            SystemOverviewCard(cpu: 26, memory: 73, disk: 52)
        }
        .padding(16)
        .background(InkPalette.paper)
    }
}
#endif
