import Foundation
import Testing

@testable import JingshanCore

@Suite("AppCacheCatalog")
struct AppCacheCatalogTests {
    @Test("bundled JSON resource parses into a non-empty entry set")
    func bundledResourceLoads() {
        #expect(!AppCacheCatalog.default.entries.isEmpty)
    }

    @Test("recognizes common developer tools")
    func recognizesDevTools() {
        let match = AppCacheCatalog.default.classify(name: "com.microsoft.VSCode")
        #expect(match?.group == .devTools)
        #expect(match?.displayName == "Visual Studio Code")
    }

    @Test("recognizes common communication apps")
    func recognizesCommunicationApps() {
        #expect(AppCacheCatalog.default.classify(name: "com.tencent.xinWeChat")?.group == .communication)
        #expect(AppCacheCatalog.default.classify(name: "com.tencent.WeWorkMac")?.group == .communication)
    }

    @Test("wildcard patterns match variants")
    func wildcardMatchesVariants() {
        let catalog = AppCacheCatalog(entries: [.init(namePattern: "com.jetbrains.*", displayName: "JetBrains IDE", group: .devTools)])
        #expect(catalog.classify(name: "com.jetbrains.intellij")?.displayName == "JetBrains IDE")
        #expect(catalog.classify(name: "com.other.app") == nil)
    }

    @Test("unrecognized name returns nil rather than a guess")
    func unrecognizedNameReturnsNil() {
        #expect(AppCacheCatalog.default.classify(name: "com.totally.unknown.app.xyz123") == nil)
    }
}
