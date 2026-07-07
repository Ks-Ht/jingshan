#if DEBUG
import AppKit
import JingshanCore
import SwiftUI

/// Renders key screens to PNGs entirely in-process via `ImageRenderer` — no
/// screen-recording permission needed (an app rendering its own SwiftUI
/// content is not a screen capture). Triggered by launching with the env var
/// `JINGSHAN_SNAPSHOT=1`; writes to /tmp/jingshan-snapshots and exits. This
/// is the only way to actually *see* the native rendering in this dev setup,
/// where the terminal process lacks Screen Recording access.
enum SnapshotHarness {
    @MainActor
    static func runIfRequested() {
        guard ProcessInfo.processInfo.environment["JINGSHAN_SNAPSHOT"] == "1" else { return }

        let dir = "/tmp/jingshan-snapshots"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        render(
            HomeSnapshotContent()
                .frame(width: 980)
                .fixedSize(horizontal: false, vertical: true),
            to: "\(dir)/home.png"
        )
        render(
            VStack(spacing: 0) {
                TopNavBar(selection: .constant(.home))
                Divider().opacity(0.5)
            }
            .frame(width: 980)
            .background(InkPalette.paper),
            to: "\(dir)/topnav.png"
        )

        // A few Status Bento cards with sample data — to confirm the area-chart
        // overflow fix (the disk card's high-usage red area must stay inside
        // the rounded card, not bleed down).
        render(
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], spacing: 14) {
                // First card has no sparkline — verifies P2 bento bottom-align
                // (it must stretch to its row-mates' height) and the P2 no-wrap
                // machine-spec subtitle laid out full-width.
                HealthScoreCard(healthScorePercent: 74, worstUsagePercent: 26, machineInfo: "10 核 · 17.18 GB · 245.11 GB")
                MetricSparklineCard(title: "CPU", systemImage: "cpu", detailPrimary: "总体使用率", detailSecondary: "8 核心", percent: 26, history: [18, 24, 30, 22, 26, 24, 27, 25, 26], tint: .green)
                MetricSparklineCard(title: "内存", systemImage: "memorychip", detailPrimary: "已用 23 GB", detailSecondary: "共 32 GB", percent: 73, history: [60, 65, 70, 72, 73, 71, 73], tint: InkPalette.amber, needsAttention: true)
                MetricSparklineCard(title: "磁盘", systemImage: "internaldrive", detailPrimary: "可用 58 GB", detailSecondary: "共 494 GB", percent: 88, history: [84, 85, 86, 88, 87, 88, 88], tint: InkPalette.vermilion, needsAttention: true)
                BatteryCard(battery: BatterySnapshot(percentage: 82, isCharging: true, isPresent: true))
                PerCoreCard(perCore: [22, 48, 15, 63, 30, 12, 55, 8])
                SystemInfoCard(info: SystemInfo(modelIdentifier: "Mac15,3", osVersionString: "15.2", coreCount: 10, physicalMemoryBytes: 18_000_000_000, uptimeSeconds: 190_000, loadAverage: [1.82, 2.10, 1.95]))
                TopProcessesCard(rows: [
                    ProcessUsageRow(id: 1, pid: 411, name: "净山", cpuPercent: 6.2, memoryPercent: 1.1),
                    ProcessUsageRow(id: 2, pid: 88, name: "WindowServer", cpuPercent: 14.0, memoryPercent: 3.4),
                    ProcessUsageRow(id: 3, pid: 204, name: "Xcode", cpuPercent: 41.5, memoryPercent: 12.8),
                    ProcessUsageRow(id: 4, pid: 320, name: "Google Chrome", cpuPercent: 9.3, memoryPercent: 8.1),
                ])
            }
            .padding()
            .frame(width: 780)
            .background(InkPalette.paper),
            to: "\(dir)/status.png"
        )

        // Heroes — verify the refined ink-wash is one clean mountain
        // silhouette (no blobs/dots/sun) and buttons use module colors (not
        // system blue), with the tighter hero height.
        render(
            VStack(spacing: 16) {
                HeroHeader(motif: .clean, title: "清理", tint: InkPalette.cleanAccent) {
                    HStack(spacing: 10) {
                        Button("开始扫描") {}.buttonStyle(.bordered)
                        Button("清理") {}.buttonStyle(.borderedProminent).tint(InkPalette.cleanAccent)
                    }
                }
                .tint(InkPalette.cleanAccent)
                HeroHeader(motif: .purge, title: "构建产物", tint: InkPalette.purgeAccent) {
                    HStack(spacing: 10) {
                        Button("目录…") {}.buttonStyle(.bordered)
                        Button("开始扫描") {}.buttonStyle(.bordered)
                        Button("清理") {}.buttonStyle(.borderedProminent).tint(InkPalette.purgeAccent)
                    }
                }
                .tint(InkPalette.purgeAccent)
                HeroHeader(motif: .docker, title: "Docker", tint: InkPalette.dockerAccent) {
                    Button("清理") {}.buttonStyle(.borderedProminent).tint(InkPalette.dockerAccent)
                }
                .tint(InkPalette.dockerAccent)
            }
            .padding()
            .frame(width: 820)
            .background(InkPalette.paper),
            to: "\(dir)/heroes.png"
        )

        // Purge page — verify the P0 empty-state copy (unconfigured vs
        // scanned-empty) and that its hero/buttons read cleanly.
        render(
            PurgeView(viewModel: PurgeViewModel())
                .frame(width: 900, height: 560)
                .background(InkPalette.paper),
            to: "\(dir)/purge.png"
        )

        // Large-files module (B1) — verify the hero + empty state read cleanly.
        render(
            LargeFilesView(viewModel: LargeFilesViewModel())
                .frame(width: 900, height: 520)
                .background(InkPalette.paper),
            to: "\(dir)/largefiles.png"
        )

        // Menu-bar tray panel (A4).
        render(
            MenuBarContentView(model: MenuBarViewModel.shared)
                .background(InkPalette.paper),
            to: "\(dir)/menubar.png"
        )

        // Uninstaller — verify the P2 search field now sits inside the list
        // column (not floated into the title bar via `.searchable`) and reads
        // in-theme.
        render(
            UninstallerView(viewModel: UninstallerViewModel())
                .frame(width: 900, height: 520)
                .background(InkPalette.paper),
            to: "\(dir)/uninstaller.png"
        )

        // Module-colored checkboxes (§Part C / A6) — verify the checkmark fill
        // is the module tint, never system blue, across selected/unselected/
        // disabled states.
        render(
            VStack(alignment: .leading, spacing: 6) {
                CategoryRow(title: "Google Chrome · 浏览器缓存", subtitle: "~/Library/Caches/com.google.Chrome", sizeText: "820 MB", isSelected: true, tint: InkPalette.cleanAccent, onToggle: { _ in })
                CategoryRow(title: "Xcode · 开发者缓存", subtitle: "~/Library/Developer/Xcode/DerivedData", sizeText: "3.4 GB", isSelected: true, tint: InkPalette.cleanAccent, onToggle: { _ in })
                CategoryRow(title: "未识别来源", subtitle: "~/Library/Caches/com.unknown.thing", riskNote: "未能识别来源，默认不勾选", sizeText: "12 MB", isSelected: false, tint: InkPalette.cleanAccent, onToggle: { _ in })
                CategoryRow(title: "微信 · 沙盒容器数据", subtitle: "~/Library/Containers/com.tencent.xinWeChat", risk: .caution, sizeText: "1.2 GB", isSelected: false, isDisabled: true, disabledReason: "应用正在运行或受保护，清理时会自动跳过", tint: InkPalette.cleanAccent, onToggle: { _ in })
                CategoryRow(title: "node_modules · 构建产物", subtitle: "~/workspace/app/node_modules", sizeText: "560 MB", isSelected: true, tint: InkPalette.purgeAccent, onToggle: { _ in })
            }
            .padding(20)
            .frame(width: 720)
            .background(InkPalette.paper),
            to: "\(dir)/checkboxes.png"
        )

        // First-run welcome + the persistent FDA banner (§1/§6) — verify the
        // safety promise reads cleanly and the banner isn't garish.
        render(
            WelcomeContent(hasFullDiskAccess: false, onOpenSettings: {})
                .padding(28)
                .frame(width: 520)
                .background(InkPalette.paper),
            to: "\(dir)/welcome.png"
        )
        render(
            VStack(spacing: 0) {
                FullDiskAccessBanner()
                Color.clear.frame(height: 40)
            }
            .frame(width: 900)
            .background(InkPalette.paper),
            to: "\(dir)/fda-banner.png"
        )

        // Sanity-print the real Docker VM disk size the sparse-file fix now
        // computes (should be actual on-disk usage, not the ~228 GB logical).
        let realRaw = NSHomeDirectory() + "/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw"
        if FileManager.default.fileExists(atPath: realRaw), let allocated = FileSizeCalculator.allocatedSize(ofPath: realRaw) {
            FileHandle.standardError.write(Data("DOCKER_RAW_ALLOCATED=\(allocated) (\(ByteFormatter.string(fromBytes: allocated)))\n".utf8))
        }

        exit(0)
    }

    @MainActor
    private static func render(_ view: some View, to path: String) {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}
#endif
