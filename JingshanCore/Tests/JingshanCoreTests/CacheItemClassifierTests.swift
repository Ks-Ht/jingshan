import Foundation
import Testing

@testable import JingshanCore

@Suite("CacheItemClassifier")
struct CacheItemClassifierTests {
    private func makeItem(path: String) -> ScannableItem {
        ScannableItem(id: path, path: path, sizeBytes: 100)
    }

    @Test("trash-scanner items are always grouped as trash regardless of catalog")
    func trashScannerItemsAreTrash() {
        let classifier = CacheItemClassifier()
        let result = classifier.classify(item: makeItem(path: "/Users/me/.Trash"), scannerCategoryID: "trash")
        #expect(result.group == .trash)
    }

    @Test("dev-tool-scanner items are always grouped as devTools regardless of catalog")
    func devToolScannerItemsAreDevTools() {
        let classifier = CacheItemClassifier()
        let result = classifier.classify(
            item: makeItem(path: "/Users/me/Library/Developer/Xcode/DerivedData"),
            scannerCategoryID: "devToolCaches"
        )
        #expect(result.group == .devTools)
    }

    @Test("browser-scanner items are always grouped as browser regardless of catalog")
    func browserScannerItemsAreBrowser() {
        let classifier = CacheItemClassifier()
        let result = classifier.classify(
            item: makeItem(path: "/Users/me/Library/Caches/com.apple.Safari"),
            scannerCategoryID: "browserCaches"
        )
        #expect(result.group == .browser)
    }

    @Test("generic userCaches item matching the catalog gets a friendly name and group")
    func userCacheItemMatchingCatalog() {
        let catalog = AppCacheCatalog(entries: [.init(namePattern: "com.tencent.xinWeChat", displayName: "微信", group: .communication)])
        let classifier = CacheItemClassifier(catalog: catalog)
        let result = classifier.classify(
            item: makeItem(path: "/Users/me/Library/Caches/com.tencent.xinWeChat"),
            scannerCategoryID: "userCaches"
        )
        #expect(result.displayName == "微信")
        #expect(result.group == .communication)
    }

    @Test("unrecognized com.apple.* item gets a generic Apple system label")
    func unrecognizedAppleItemGetsGenericLabel() {
        let classifier = CacheItemClassifier(catalog: AppCacheCatalog(entries: []))
        let result = classifier.classify(
            item: makeItem(path: "/Users/me/Library/Caches/com.apple.somethingObscure"),
            scannerCategoryID: "userCaches"
        )
        #expect(result.displayName.contains("com.apple.somethingObscure"))
        #expect(result.group == .other)
    }

    @Test("unrecognized third-party bundle-id-shaped item falls back to appCache")
    func unrecognizedThirdPartyItemFallsBackToAppCache() {
        let classifier = CacheItemClassifier(catalog: AppCacheCatalog(entries: []))
        let result = classifier.classify(
            item: makeItem(path: "/Users/me/Library/Caches/com.example.SomeApp"),
            scannerCategoryID: "userCaches"
        )
        #expect(result.displayName == "com.example.SomeApp")
        #expect(result.group == .appCache)
    }

    @Test("unrecognized plain (non-dotted) name falls back to other")
    func unrecognizedPlainNameFallsBackToOther() {
        let classifier = CacheItemClassifier(catalog: AppCacheCatalog(entries: []))
        let result = classifier.classify(
            item: makeItem(path: "/Users/me/Library/Caches/SomeGenericCache"),
            scannerCategoryID: "userCaches"
        )
        // Unrecognized names are explicitly labeled as unidentified (and land
        // in `.other`, which defaults to unselected).
        #expect(result.displayName == "未识别来源（SomeGenericCache）")
        #expect(result.group == .other)
    }
}
