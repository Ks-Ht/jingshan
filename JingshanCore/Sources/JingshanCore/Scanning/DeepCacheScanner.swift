import Foundation

/// Strong-mode ("强力模式") deep scan: additional *known-safe, regenerable*
/// locations that the routine scanners deliberately skip. Every location here
/// is either a re-downloadable package-manager cache or transient system state
/// that macOS rebuilds on demand — this is intentionally NOT an "unknown means
/// deletable" sweep. All of these live OUTSIDE `~/Library/Caches`, so they
/// never double-count with `UserCacheScanner`'s generic top-level walk.
///
/// Safety posture (see `CleanViewModel`): strong-mode finds are surfaced in the
/// default-off `.deepScan` group, are never pre-selected, and still route
/// through `DeletionEngine` (Trash + critical-path denylist) exactly like every
/// other cleanup item.
public struct DeepCacheScanner: CategoryScanning {
    public let categoryID = "deepCaches"
    public let displayName = "深度扫描"

    struct Location: Sendable {
        let label: String
        let path: String
    }

    private let locations: [Location]

    public init(homeDirectory: String = NSHomeDirectory()) {
        self.locations = [
            // Window-restore state — safe to clear, macOS rebuilds it.
            Location(label: "已保存的应用窗口状态", path: homeDirectory + "/Library/Saved Application State"),
            // Re-downloadable package-manager stores/caches, all outside ~/Library/Caches.
            Location(label: "Yarn 缓存 (Berry)", path: homeDirectory + "/.yarn/cache"),
            Location(label: "pnpm store", path: homeDirectory + "/Library/pnpm/store"),
            Location(label: "Bun 缓存", path: homeDirectory + "/.bun/install/cache"),
            Location(label: "Go 模块下载缓存", path: homeDirectory + "/go/pkg/mod/cache/download"),
            Location(label: "CocoaPods 缓存", path: homeDirectory + "/.cocoapods/repos"),
            Location(label: "Puppeteer 浏览器缓存", path: homeDirectory + "/.cache/puppeteer"),
        ]
    }

    public func scan() async -> ScanCategory {
        var items: [ScannableItem] = []
        for location in locations {
            if Task.isCancelled { break }
            if let item = await ScanningSupport.scanWholeDirectory(at: location.path, displayLabel: location.label) {
                items.append(item)
            }
        }
        return ScanCategory(id: categoryID, displayName: displayName, items: items)
    }
}
