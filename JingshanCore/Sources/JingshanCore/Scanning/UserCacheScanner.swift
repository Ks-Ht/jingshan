import Foundation

/// `~/Library/Caches`, one row per subfolder (conventionally one per
/// bundle identifier). Browser and dev-tool cache folders living directly
/// under here are excluded since `BrowserCacheScanner`/`DevToolCacheScanner`
/// cover them with more specific knowledge (nested profile paths, friendly
/// labels) — this avoids the same folder showing up twice, in two
/// different categories, with its size double-counted in both.
public struct UserCacheScanner: CategoryScanning {
    public let categoryID = "userCaches"
    public let displayName = "用户缓存"

    private let directoryPath: String
    private let excludedNames: Set<String>

    public init(
        directoryPath: String = NSHomeDirectory() + "/Library/Caches",
        excludedNames: Set<String> = BrowserCacheScanner.topLevelCacheNamesToExcludeFromGenericScan
            .union(DevToolCacheScanner.topLevelCacheNamesToExcludeFromGenericScan)
    ) {
        self.directoryPath = directoryPath
        self.excludedNames = excludedNames
    }

    public func scan() async -> ScanCategory {
        let items = await ScanningSupport.scanImmediateChildren(
            of: directoryPath,
            excludedNames: excludedNames,
            ownerAppBundleID: { ScanningSupport.looksLikeBundleIdentifier($0) ? $0 : nil }
        )
        return ScanCategory(id: categoryID, displayName: displayName, items: items)
    }
}
