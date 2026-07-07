import Foundation
import Testing

@testable import JingshanCore

@Suite("ProtectionEvaluator")
struct ProtectionEvaluatorTests {
    @Test("nil bundle identifier is never protected")
    func nilIsNeverProtected() {
        let evaluator = ProtectionEvaluator()
        #expect(evaluator.evaluate(bundleIdentifier: nil) == .notProtected)
    }

    @Test("static allowlist match wins over running-app state")
    func staticAllowlistTakesPriority() {
        let protectedApps = ProtectedAppAllowlist(entries: [.init(bundleIdentifierPattern: "com.apple.*", reason: "test")])
        let runningChecker = FakeRunningApplicationChecker(runningBundleIdentifiers: ["com.apple.Safari"])
        let evaluator = ProtectionEvaluator(protectedApps: protectedApps, runningChecker: runningChecker)

        guard case .staticallyProtected = evaluator.evaluate(bundleIdentifier: "com.apple.Safari") else {
            Issue.record("expected staticallyProtected")
            return
        }
    }

    @Test("a running (but not statically protected) app is reported as overridable")
    func runningAppIsReportedSeparately() {
        let protectedApps = ProtectedAppAllowlist(entries: [])
        let runningChecker = FakeRunningApplicationChecker(runningBundleIdentifiers: ["com.example.App"])
        let evaluator = ProtectionEvaluator(protectedApps: protectedApps, runningChecker: runningChecker)

        guard case .runningApp = evaluator.evaluate(bundleIdentifier: "com.example.App") else {
            Issue.record("expected runningApp")
            return
        }
    }

    @Test("an unprotected, non-running app is not protected")
    func notProtectedWhenNeitherApplies() {
        let protectedApps = ProtectedAppAllowlist(entries: [])
        let runningChecker = FakeRunningApplicationChecker()
        let evaluator = ProtectionEvaluator(protectedApps: protectedApps, runningChecker: runningChecker)

        #expect(evaluator.evaluate(bundleIdentifier: "com.example.App") == .notProtected)
    }
}
