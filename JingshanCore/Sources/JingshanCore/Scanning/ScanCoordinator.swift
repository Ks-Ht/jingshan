import Foundation

/// Runs every category scanner in turn and reports incremental progress.
/// An `actor` so a scan in flight can be safely cancelled or queried from
/// any calling context without extra locking.
public actor ScanCoordinator {
    private let scanners: [any CategoryScanning]

    public init(scanners: [any CategoryScanning] = ScanCoordinator.defaultScanners()) {
        self.scanners = scanners
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

    /// Scans every category sequentially (deliberately not parallel, to
    /// avoid saturating disk I/O with concurrent tree walks) and reports
    /// each category's result as it finishes via `onCategoryComplete`.
    /// Cooperatively cancellable: checks `Task.isCancelled` between
    /// categories, and each scanner checks it internally too.
    public func scan(onCategoryComplete: (@Sendable (ScanCategory) -> Void)? = nil) async -> [ScanCategory] {
        var results: [ScanCategory] = []
        for scanner in scanners {
            if Task.isCancelled { break }
            let category = await scanner.scan()
            results.append(category)
            onCategoryComplete?(category)
        }
        return results
    }
}
