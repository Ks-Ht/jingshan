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

    struct ChromiumRoot: Sendable {
        let browserName: String
        let bundleIdentifier: String
        let path: String
    }

    private let candidateLocations: [Location]
    private let chromiumRoots: [ChromiumRoot]

    private static let chromiumCacheNames = [
        "Cache", "Code Cache", "GPUCache", "ShaderCache", "GrShaderCache", "DawnCache",
    ]

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
        self.chromiumRoots = [
            ChromiumRoot(browserName: "Google Chrome", bundleIdentifier: "com.google.Chrome", path: homeDirectory + "/Library/Application Support/Google/Chrome"),
            ChromiumRoot(browserName: "Microsoft Edge", bundleIdentifier: "com.microsoft.edgemac", path: homeDirectory + "/Library/Application Support/Microsoft Edge"),
            ChromiumRoot(browserName: "Arc", bundleIdentifier: "company.thebrowser.Browser", path: homeDirectory + "/Library/Application Support/Arc/User Data"),
        ]
    }

    public func scan() async -> ScanCategory {
        var items: [ScannableItem] = []
        var issues: [ScanIssue] = []
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
        for root in chromiumRoots {
            if Task.isCancelled { break }
            let result = await scanChromiumProfiles(in: root)
            items.append(contentsOf: result.items)
            issues.append(contentsOf: result.issues)
        }
        return ScanCategory(id: categoryID, displayName: displayName, items: items, issues: issues)
    }

    private func scanChromiumProfiles(in root: ChromiumRoot) async -> (items: [ScannableItem], issues: [ScanIssue]) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: root.path) else { return ([], []) }
        let entries: [String]
        do {
            entries = try fileManager.contentsOfDirectory(atPath: root.path)
        } catch {
            return ([], [ScanIssue(id: PathValidator.normalize(root.path), message: "无法读取 \(root.browserName) 数据，浏览器扫描不完整")])
        }
        let profiles = entries.filter { $0 == "Default" || $0.hasPrefix("Profile ") }
        var items: [ScannableItem] = []
        for profile in profiles.sorted() {
            for cacheName in Self.chromiumCacheNames {
                if Task.isCancelled { return (items, []) }
                let path = root.path + "/" + profile + "/" + cacheName
                guard fileManager.fileExists(atPath: path) else { continue }
                items.append(
                    ScannableItem(
                        id: PathValidator.normalize(path),
                        path: path,
                        sizeBytes: await FileSizeCalculator.sizeAsync(ofPath: path),
                        ownerAppBundleID: root.bundleIdentifier,
                        displayLabel: "\(root.browserName) · \(profile) · \(cacheName)"
                    )
                )
            }
        }
        return (items, [])
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
