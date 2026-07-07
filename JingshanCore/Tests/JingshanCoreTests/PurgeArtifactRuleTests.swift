import Foundation
import Testing

@testable import JingshanCore

@Suite("PurgeArtifactRule")
struct PurgeArtifactRuleTests {
    @Test("a marker-gated rule only matches when a required sibling is present")
    func markerGatedRuleRequiresSibling() {
        let rule = PurgeArtifactRule(directoryName: "node_modules", displayLabel: "node_modules", requiredSiblingMarkers: ["package.json"], riskNote: "note")

        #expect(rule.isSatisfied(bySiblingNames: ["package.json", "src"]))
        #expect(!rule.isSatisfied(bySiblingNames: ["src", "README.md"]))
    }

    @Test("a rule with multiple acceptable markers matches on any one of them")
    func multipleMarkersAnyOneMatches() {
        let rule = PurgeArtifactRule(directoryName: "target", displayLabel: "target", requiredSiblingMarkers: ["Cargo.toml", "pom.xml"], riskNote: "note")

        #expect(rule.isSatisfied(bySiblingNames: ["Cargo.toml"]))
        #expect(rule.isSatisfied(bySiblingNames: ["pom.xml"]))
        #expect(!rule.isSatisfied(bySiblingNames: ["package.json"]))
    }

    @Test("a rule with no required markers always matches (e.g. __pycache__)")
    func noMarkersAlwaysMatches() {
        let rule = PurgeArtifactRule(directoryName: "__pycache__", displayLabel: "__pycache__", requiredSiblingMarkers: [], riskNote: "note")
        #expect(rule.isSatisfied(bySiblingNames: []))
        #expect(rule.isSatisfied(bySiblingNames: ["anything.txt"]))
    }

    @Test("default rules parse and every rule has a non-empty display label and risk note")
    func defaultRulesAreWellFormed() {
        #expect(!PurgeArtifactRule.defaultRules.isEmpty)
        for rule in PurgeArtifactRule.defaultRules {
            #expect(!rule.directoryName.isEmpty)
            #expect(!rule.displayLabel.isEmpty)
            #expect(!rule.riskNote.isEmpty)
        }
    }
}
