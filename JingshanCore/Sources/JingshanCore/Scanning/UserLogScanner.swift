import Foundation

/// `~/Library/Logs`, one row per subfolder/file. Jingshan's own log
/// directory is excluded so the app never offers to delete the audit
/// trail it just wrote.
public struct UserLogScanner: CategoryScanning {
    public let categoryID = "userLogs"
    public let displayName = "用户日志"

    private let directoryPath: String
    private let excludedNames: Set<String>

    public init(
        directoryPath: String = NSHomeDirectory() + "/Library/Logs",
        excludedNames: Set<String> = ["Jingshan"]
    ) {
        self.directoryPath = directoryPath
        self.excludedNames = excludedNames
    }

    public func scan() async -> ScanCategory {
        let result = await ScanningSupport.scanImmediateChildren(
            of: directoryPath,
            excludedNames: excludedNames
        )
        return ScanCategory(id: categoryID, displayName: displayName, items: result.items, issues: result.issues)
    }
}
