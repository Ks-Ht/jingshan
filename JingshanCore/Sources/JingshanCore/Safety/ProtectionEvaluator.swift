import Foundation

/// Single source of truth for "is this bundle identifier protected right
/// now, and can that be overridden". Used by `DeletionEngine` to enforce
/// the policy, and reusable by UI code that wants to preview the same
/// verdict before the user even attempts a delete.
public struct ProtectionEvaluator: Sendable {
    public enum Verdict: Equatable, Sendable {
        case notProtected
        /// Matches the static allowlist (e.g. Apple system bundle ids).
        /// Never overridable.
        case staticallyProtected(reason: String)
        /// The app is currently running. Overridable via
        /// `allowProtectedAppOverride` at the call site.
        case runningApp(reason: String)
    }

    private let protectedApps: ProtectedAppAllowlist
    private let runningChecker: RunningApplicationChecking

    public init(
        protectedApps: ProtectedAppAllowlist = .default,
        runningChecker: RunningApplicationChecking = WorkspaceRunningApplicationChecker()
    ) {
        self.protectedApps = protectedApps
        self.runningChecker = runningChecker
    }

    public func evaluate(bundleIdentifier: String?) -> Verdict {
        guard let bundleIdentifier else { return .notProtected }
        if protectedApps.isProtected(bundleIdentifier: bundleIdentifier) {
            return .staticallyProtected(reason: "在受保护应用名单中，不可覆盖")
        }
        if runningChecker.isApplicationRunning(bundleIdentifier: bundleIdentifier) {
            return .runningApp(reason: "应用正在运行")
        }
        return .notProtected
    }
}
