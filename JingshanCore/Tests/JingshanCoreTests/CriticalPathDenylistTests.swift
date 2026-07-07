import Foundation
import Testing

@testable import JingshanCore

@Suite("CriticalPathDenylist")
struct CriticalPathDenylistTests {
    @Test("bundled JSON resource parses into a non-empty rule set")
    func bundledResourceLoads() {
        #expect(!CriticalPathDenylist.default.rules.isEmpty)
    }

    @Test("exactPath rule matches only the literal path, not its children")
    func exactPathRuleDoesNotMatchChildren() {
        let denylist = CriticalPathDenylist(rules: [
            .init(pathPrefix: "/Applications", matchType: .exactPath, reason: "test")
        ])
        #expect(denylist.firstMatch(forResolvedPath: "/Applications") != nil)
        #expect(denylist.firstMatch(forResolvedPath: "/Applications/Safari.app") == nil)
    }

    @Test("prefixOfDirectory rule matches the directory itself and everything nested inside it")
    func prefixRuleMatchesSelfAndDescendants() {
        let denylist = CriticalPathDenylist(rules: [
            .init(pathPrefix: "/System", matchType: .prefixOfDirectory, reason: "test")
        ])
        #expect(denylist.firstMatch(forResolvedPath: "/System") != nil)
        #expect(denylist.firstMatch(forResolvedPath: "/System/Library/CoreServices") != nil)
        #expect(denylist.firstMatch(forResolvedPath: "/SystemOther") == nil)
    }

    @Test("does not match an unrelated sibling directory with a similar name")
    func doesNotMatchSimilarlyNamedSibling() {
        let denylist = CriticalPathDenylist(rules: [
            .init(pathPrefix: "/usr/lib", matchType: .prefixOfDirectory, reason: "test")
        ])
        #expect(denylist.firstMatch(forResolvedPath: "/usr/local") == nil)
        #expect(denylist.firstMatch(forResolvedPath: "/usr/libexec") == nil)
    }
}
