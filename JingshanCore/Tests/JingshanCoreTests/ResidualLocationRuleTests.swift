import Foundation
import Testing

@testable import JingshanCore

@Suite("ResidualLocationRule")
struct ResidualLocationRuleTests {
    private let app = InstalledApplication(
        path: "/Applications/Example.app",
        bundleIdentifier: "com.example.app",
        displayName: "Example",
        versionString: "1.0"
    )

    @Test("a bundle-identifier-keyed rule computes the path from the bundle id")
    func bundleIdentifierKeyedPath() {
        let rule = ResidualLocationRule(
            relativeDirectory: "Library/Caches",
            matchKey: .bundleIdentifier,
            displayLabel: "缓存",
            tier: .safe,
            riskNote: "note"
        )
        let path = rule.expectedPath(for: app, homeDirectory: "/Users/tester")
        #expect(path == "/Users/tester/Library/Caches/com.example.app")
    }

    @Test("a display-name-keyed rule computes the path from the display name, not the bundle id")
    func displayNameKeyedPath() {
        let rule = ResidualLocationRule(
            relativeDirectory: "Library/Logs",
            matchKey: .displayName,
            displayLabel: "日志",
            tier: .safe,
            riskNote: "note"
        )
        let path = rule.expectedPath(for: app, homeDirectory: "/Users/tester")
        #expect(path == "/Users/tester/Library/Logs/Example")
    }

    @Test("a path suffix is appended after the matched key, for file-style (not directory) locations")
    func pathSuffixAppended() {
        let rule = ResidualLocationRule(
            relativeDirectory: "Library/Preferences",
            matchKey: .bundleIdentifier,
            pathSuffix: ".plist",
            displayLabel: "偏好设置",
            tier: .caution,
            riskNote: "note"
        )
        let path = rule.expectedPath(for: app, homeDirectory: "/Users/tester")
        #expect(path == "/Users/tester/Library/Preferences/com.example.app.plist")
    }

    @Test("only the safe tier is selected by default — caution and destructive both require opt-in")
    func defaultSelectabilityByTier() {
        #expect(ResidualRiskTier.safe.isDefaultSelectable)
        #expect(!ResidualRiskTier.caution.isDefaultSelectable)
        #expect(!ResidualRiskTier.destructive.isDefaultSelectable)
    }

    @Test("default rules are well-formed: non-empty labels and risk notes")
    func defaultRulesAreWellFormed() {
        #expect(!ResidualLocationRule.defaultRules.isEmpty)
        for rule in ResidualLocationRule.defaultRules {
            #expect(!rule.relativeDirectory.isEmpty)
            #expect(!rule.displayLabel.isEmpty)
            #expect(!rule.riskNote.isEmpty)
        }
    }

    @Test("the Containers rule (the one location that can hold real app data) is tiered destructive")
    func containersRuleIsDestructive() throws {
        let containersRule = try #require(
            ResidualLocationRule.defaultRules.first { $0.relativeDirectory == "Library/Containers" }
        )
        #expect(containersRule.tier == .destructive)
    }
}
