import Foundation

/// Turns a raw scanned item into what the user actually sees: a friendly
/// name and a real-world group, regardless of which scanner produced it.
public struct CacheItemClassifier: Sendable {
    private let catalog: AppCacheCatalog

    public init(catalog: AppCacheCatalog = .default) {
        self.catalog = catalog
    }

    /// `scannerCategoryID` is `ScanCategory.id` from whichever scanner
    /// produced this item. Scanners that already know their own group
    /// (trash, dev tool caches, browser caches) short-circuit straight to
    /// it; only the generic user-cache/user-log scanners need a real
    /// lookup, since that is the only place a bare bundle identifier ever
    /// reaches the UI unlabeled.
    public func classify(item: ScannableItem, scannerCategoryID: String) -> (displayName: String, group: CacheGroup) {
        switch scannerCategoryID {
        case "trash":
            return (item.resolvedDisplayLabel, .trash)
        case "devToolCaches":
            return (item.resolvedDisplayLabel, .devTools)
        case "browserCaches":
            return (item.resolvedDisplayLabel, .browser)
        case "deepCaches":
            // Strong-mode finds get their own group (default-off) so they're
            // visibly separated from the routine, pre-selected categories.
            return (item.resolvedDisplayLabel, .deepScan)
        default:
            let rawName = (item.path as NSString).lastPathComponent
            if let match = catalog.classify(name: rawName) {
                return match
            }
            if rawName.hasPrefix("com.apple.") {
                return ("Apple 系统组件（\(rawName)）", .other)
            }
            if ScanningSupport.looksLikeBundleIdentifier(rawName) {
                return (rawName, .appCache)
            }
            // Couldn't attribute this to any known app/system source. Label it
            // explicitly as unidentified (it lands in `.other`, which defaults
            // to unselected) so the user never silently deletes a black box.
            return ("未识别来源（\(rawName)）", .other)
        }
    }
}
