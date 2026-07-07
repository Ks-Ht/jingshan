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

        // Uninstaller — verify the P2 search field now sits inside the list
        // column (not floated into the title bar via `.searchable`) and reads
        // in-theme.
        render(
            UninstallerView(viewModel: UninstallerViewModel())
                .frame(width: 900, height: 520)
                .background(InkPalette.paper),
            to: "\(dir)/uninstaller.png"
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
