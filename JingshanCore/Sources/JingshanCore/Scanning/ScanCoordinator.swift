import Foundation

/// Runs every category scanner in turn and reports incremental progress.
/// An `actor` so a scan in flight can be safely cancelled or queried from
/// any calling context without extra locking.
public actor ScanCoordinator {
    private let scanners: [any CategoryScanning]
    /// Extra scanners run only in strong ("深度") mode — appended after the
    /// routine set. Kept separate so a normal scan never touches them.
    private let deepScanners: [any CategoryScanning]

    public init(
        scanners: [any CategoryScanning] = ScanCoordinator.defaultScanners(),
        deepScanners: [any CategoryScanning] = ScanCoordinator.defaultDeepScanners()
    ) {
        self.scanners = scanners
        self.deepScanners = deepScanners
    }

    public static func defaultScanners() -> [any CategoryScanning] {
        [
            UserCacheScanner(),
            BrowserCacheScanner(),
            UserLogScanner(),
            TrashScanner(),
            DevToolCacheScanner(),
        ]
    }

    public static func defaultDeepScanners() -> [any CategoryScanning] {
        [DeepCacheScanner()]
    }

    /// Scans every category sequentially (deliberately not parallel, to
    /// avoid saturating disk I/O with concurrent tree walks) and reports
    /// each category's result as it finishes via `onCategoryComplete`.
    /// Cooperatively cancellable: checks `Task.isCancelled` between
    /// categories, and each scanner checks it internally too.
    public func scan(deep: Bool = false, onCategoryComplete: (@Sendable (ScanCategory) -> Void)? = nil) async -> [ScanCategory] {
        var results: [ScanCategory] = []
        let active = deep ? scanners + deepScanners : scanners
        for scanner in active {
            if Task.isCancelled { break }
            let category = await scanner.scan()
            results.append(category)
            onCategoryComplete?(category)
        }
        return results
    }
}
