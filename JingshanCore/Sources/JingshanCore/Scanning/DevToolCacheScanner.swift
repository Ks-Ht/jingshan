import Foundation

/// Developer-tool caches. Xcode DerivedData is the flagship v1 target
/// (typically the single largest reclaimable item on a dev machine); the
/// rest are existence-checked so the category only shows what the user
/// actually has installed.
public struct DevToolCacheScanner: CategoryScanning {
    public let categoryID = "devToolCaches"
    public let displayName = "开发工具缓存"

    struct Location: Sendable {
        let label: String
        let path: String
    }

    private let locations: [Location]

    public init(homeDirectory: String = NSHomeDirectory()) {
        self.locations = [
            Location(label: "Xcode DerivedData", path: homeDirectory + "/Library/Developer/Xcode/DerivedData"),
            Location(label: "Xcode Archives", path: homeDirectory + "/Library/Developer/Xcode/Archives"),
            Location(label: "iOS 设备支持文件", path: homeDirectory + "/Library/Developer/Xcode/iOS DeviceSupport"),
            Location(label: "模拟器缓存", path: homeDirectory + "/Library/Developer/CoreSimulator/Caches"),
            Location(label: "SwiftPM 缓存", path: homeDirectory + "/Library/Caches/org.swift.swiftpm"),
            Location(label: "Homebrew 缓存", path: homeDirectory + "/Library/Caches/Homebrew"),
            Location(label: "npm 缓存", path: homeDirectory + "/.npm"),
            Location(label: "pip 缓存", path: homeDirectory + "/Library/Caches/pip"),
            Location(label: "Cargo 缓存", path: homeDirectory + "/.cargo/registry/cache"),
            Location(label: "Gradle 缓存", path: homeDirectory + "/.gradle/caches"),
            Location(label: "通用缓存 (~/.cache)", path: homeDirectory + "/.cache"),
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

    /// Top-level `~/Library/Caches` folder names already covered by this
    /// scanner's own location list (SwiftPM, Homebrew, pip), so
    /// `UserCacheScanner`'s generic walk can skip them and avoid listing —
    /// and double-counting the size of — the same folder twice. Everything
    /// else in the location list above (Xcode DerivedData/Archives, iOS
    /// DeviceSupport, CoreSimulator caches, npm/Cargo/Gradle/`~/.cache`)
    /// lives outside `~/Library/Caches` entirely, so it needs no entry here.
    public static let topLevelCacheNamesToExcludeFromGenericScan: Set<String> = [
        "org.swift.swiftpm",
        "Homebrew",
        "pip",
    ]
}
