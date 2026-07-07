import Foundation
import Testing

@testable import JingshanCore

/// The plumbing behind Clean's "强力模式": the extra deep scanners must run
/// ONLY when `deep: true` is requested, never during a routine scan.
@Suite("StrongModeScan")
struct StrongModeScanTests {
    private struct FakeScanner: CategoryScanning {
        let categoryID: String
        let displayName: String
        func scan() async -> ScanCategory {
            ScanCategory(id: categoryID, displayName: displayName, items: [])
        }
    }

    @Test("a normal scan never runs the deep scanners")
    func normalScanSkipsDeep() async {
        let coordinator = ScanCoordinator(
            scanners: [FakeScanner(categoryID: "routine", displayName: "routine")],
            deepScanners: [FakeScanner(categoryID: "deepCaches", displayName: "深度扫描")]
        )
        let results = await coordinator.scan(deep: false)
        #expect(results.map(\.id) == ["routine"])
        #expect(!results.contains { $0.id == "deepCaches" })
    }

    @Test("a deep scan appends the deep scanners after the routine ones")
    func deepScanIncludesDeep() async {
        let coordinator = ScanCoordinator(
            scanners: [FakeScanner(categoryID: "routine", displayName: "routine")],
            deepScanners: [FakeScanner(categoryID: "deepCaches", displayName: "深度扫描")]
        )
        let results = await coordinator.scan(deep: true)
        #expect(results.map(\.id) == ["routine", "deepCaches"])
    }

    @Test("the deepScan display group defaults to unselected")
    func deepScanGroupDefaultsOff() {
        #expect(CacheGroup.deepScan.defaultSelected == false)
    }

    @Test("deep-scanner items classify into the deepScan group")
    func deepItemsClassifyToDeepScan() {
        let classifier = CacheItemClassifier(catalog: AppCacheCatalog(entries: []))
        let item = ScannableItem(id: "x", path: "/Users/me/.yarn/cache", sizeBytes: 100)
        let result = classifier.classify(item: item, scannerCategoryID: "deepCaches")
        #expect(result.group == .deepScan)
    }
}
