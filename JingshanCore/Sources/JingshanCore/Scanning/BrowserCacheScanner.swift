import Foundation

/// Known browser cache locations, existence-checked individually. Browsers
/// scatter their cache across locations a flat `~/Library/Caches` walk
/// would not fully capture (nested profile directories, sandboxed
/// container paths), so each gets an explicit, named entry rather than
/// relying on generic directory enumeration.
public struct BrowserCacheScanner: CategoryScanning {
    public let categoryID = "browserCaches"
    public let displayName = "浏览器缓存"

    struct Location: Sendable {
        let browserName: String
        let bundleIdentifier: String?
        let path: String
    }

    private let candidateLocations: [Location]

    public init(homeDirectory: String = NSHomeDirectory()) {
        self.candidateLocations = [
            Location(
                browserName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                path: homeDirectory + "/Library/Caches/com.apple.Safari"
            ),
            Location(
                browserName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                path: homeDirectory + "/Library/Containers/com.apple.Safari/Data/Library/Caches"
            ),
            Location(
                browserName: "Google Chrome",
                bundleIdentifier: "com.google.Chrome",
                path: homeDirectory + "/Library/Caches/Google/Chrome"
            ),
            Location(
                browserName: "Microsoft Edge",
                bundleIdentifier: "com.microsoft.edgemac",
                path: homeDirectory + "/Library/Caches/Microsoft Edge"
            ),
            Location(
                browserName: "Firefox",
                bundleIdentifier: "org.mozilla.firefox",
                path: homeDirectory + "/Library/Caches/Firefox"
            ),
            Location(
                browserName: "Arc",
                bundleIdentifier: "company.thebrowser.Browser",
                path: homeDirectory + "/Library/Caches/company.thebrowser.Browser"
            ),
        ]
    }

    public func scan() async -> ScanCategory {
        var items: [ScannableItem] = []
        for location in candidateLocations {
            if Task.isCancelled { break }
            guard FileManager.default.fileExists(atPath: location.path) else { continue }
            let size = await FileSizeCalculator.sizeAsync(ofPath: location.path)
            items.append(
                ScannableItem(
                    id: PathValidator.normalize(location.path),
                    path: location.path,
                    sizeBytes: size,
                    ownerAppBundleID: location.bundleIdentifier,
                    displayLabel: location.browserName
                )
            )
        }
        return ScanCategory(id: categoryID, displayName: displayName, items: items)
    }

    /// Top-level `~/Library/Caches` folder names already covered by this
    /// scanner's own candidate list, so `UserCacheScanner`'s generic walk
    /// can skip them and avoid listing the same folder twice.
    public static let topLevelCacheNamesToExcludeFromGenericScan: Set<String> = [
        "com.apple.Safari",
        "Google",
        "Microsoft Edge",
        "Firefox",
        "company.thebrowser.Browser",
    ]
}
