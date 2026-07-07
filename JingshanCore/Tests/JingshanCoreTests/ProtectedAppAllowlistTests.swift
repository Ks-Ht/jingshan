import Foundation
import Testing

@testable import JingshanCore

@Suite("ProtectedAppAllowlist")
struct ProtectedAppAllowlistTests {
    @Test("bundled JSON resource parses into a non-empty entry set")
    func bundledResourceLoads() {
        #expect(!ProtectedAppAllowlist.default.entries.isEmpty)
    }

    @Test("wildcard pattern protects every matching bundle identifier")
    func wildcardMatches() {
        let allowlist = ProtectedAppAllowlist(entries: [
            .init(bundleIdentifierPattern: "com.apple.*", reason: "test")
        ])
        #expect(allowlist.isProtected(bundleIdentifier: "com.apple.Safari"))
        #expect(allowlist.isProtected(bundleIdentifier: "com.apple.finder"))
        #expect(!allowlist.isProtected(bundleIdentifier: "com.google.Chrome"))
    }

    @Test("exact pattern without a wildcard matches only that identifier")
    func exactMatchOnly() {
        let allowlist = ProtectedAppAllowlist(entries: [
            .init(bundleIdentifierPattern: "net.kongshan.jingshan", reason: "test")
        ])
        #expect(allowlist.isProtected(bundleIdentifier: "net.kongshan.jingshan"))
        #expect(!allowlist.isProtected(bundleIdentifier: "net.kongshan.jingshan.helper"))
    }

    @Test("default allowlist protects Apple system bundle identifiers")
    func defaultProtectsApple() {
        #expect(ProtectedAppAllowlist.default.isProtected(bundleIdentifier: "com.apple.Safari"))
        #expect(!ProtectedAppAllowlist.default.isProtected(bundleIdentifier: "com.example.SomeThirdPartyApp"))
    }
}
