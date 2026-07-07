import AppKit
import Foundation

/// Abstracts "is this bundle identifier currently running" so
/// `DeletionEngine` can be unit tested without depending on the real
/// `NSWorkspace` (and the set of apps happening to run on the test machine).
public protocol RunningApplicationChecking: Sendable {
    func isApplicationRunning(bundleIdentifier: String) -> Bool
}

public struct WorkspaceRunningApplicationChecker: RunningApplicationChecking {
    public init() {}

    public func isApplicationRunning(bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleIdentifier }
    }
}
