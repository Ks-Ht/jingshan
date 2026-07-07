import JingshanCore
import SwiftUI

/// Lightweight, throttled sampler dedicated to the menu-bar tray — samples
/// every few seconds (not every second like the Status page) to keep the
/// background cost low, as the spec asks. A singleton so both the tray icon
/// and its popover panel read the same live snapshot.
@MainActor
@Observable
final class MenuBarViewModel {
    static let shared = MenuBarViewModel()

    private(set) var snapshot: SystemSnapshot = .empty
    private let sampler = SystemMetricsSampler()
    private var task: Task<Void, Never>?

    var hasSample: Bool { snapshot.timestamp != .distantPast }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.snapshot = await self.sampler.sample()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}

/// The tray icon: the ink-mountain mark, or live CPU% text if the user chose
/// that style in Settings.
struct MenuBarLabel: View {
    let model: MenuBarViewModel
    let showsPercent: Bool

    var body: some View {
        if showsPercent, model.hasSample {
            Text("\(Int(model.snapshot.cpu.totalUsagePercent.rounded()))%")
        } else {
            Image(systemName: "mountain.2.fill")
        }
    }
}

/// The popover panel shown when the tray icon is clicked.
struct MenuBarContentView: View {
    let model: MenuBarViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "mountain.2.fill").foregroundStyle(InkPalette.accent)
                Text("净山").font(.headline)
                Spacer()
            }
            Divider()
            if model.hasSample {
                metricRow("CPU", model.snapshot.cpu.totalUsagePercent, .green)
                metricRow("内存", model.snapshot.memory.usedPercent, InkPalette.amber)
                metricRow("磁盘", model.snapshot.disk.usedPercent, InkPalette.coolCyan)
                if let battery = model.snapshot.battery, battery.isPresent {
                    HStack {
                        Text("电池").font(.caption).foregroundStyle(.secondary).frame(width: 34, alignment: .leading)
                        Spacer()
                        Text("\(battery.percentage)%\(battery.isCharging ? " · 充电中" : "")")
                            .font(.caption.weight(.semibold)).monospacedDigit()
                    }
                }
            } else {
                Text("正在采集…").font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            } label: {
                Label("打开净山", systemImage: "square.and.arrow.up.on.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(InkPalette.accent)
            Button("退出净山") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 250)
        .task { model.start() }
    }

    private func metricRow(_ label: String, _ percent: Double, _ tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 34, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(tint).frame(width: geo.size.width * CGFloat(min(max(percent, 0), 100) / 100))
                }
            }
            .frame(height: 5)
            Text("\(Int(percent.rounded()))%")
                .font(.caption.weight(.semibold)).monospacedDigit()
                .frame(width: 38, alignment: .trailing)
        }
    }
}
