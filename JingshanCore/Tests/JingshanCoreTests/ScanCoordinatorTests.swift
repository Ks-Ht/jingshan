import Foundation
import Testing

@testable import JingshanCore

@Suite("ScanCoordinator")
struct ScanCoordinatorTests {
    @Test("scans every configured scanner in order and returns all category results")
    func scansAllCategoriesInOrder() async {
        let scanners: [any CategoryScanning] = [
            FakeCategoryScanner(categoryID: "a", items: [ScannableItem(id: "/a/1", path: "/a/1", sizeBytes: 100)]),
            FakeCategoryScanner(categoryID: "b", items: [ScannableItem(id: "/b/1", path: "/b/1", sizeBytes: 200)]),
        ]
        let coordinator = ScanCoordinator(scanners: scanners)

        let results = await coordinator.scan()

        #expect(results.map(\.id) == ["a", "b"])
        #expect(results[0].totalSizeBytes == 100)
        #expect(results[1].totalSizeBytes == 200)
    }

    @Test("invokes the completion callback once per category as it finishes")
    func invokesCompletionPerCategory() async {
        let scanners: [any CategoryScanning] = [
            FakeCategoryScanner(categoryID: "a"),
            FakeCategoryScanner(categoryID: "b"),
            FakeCategoryScanner(categoryID: "c"),
        ]
        let coordinator = ScanCoordinator(scanners: scanners)
        let collected = CollectedIDs()

        _ = await coordinator.scan { category in
            collected.append(category.id)
        }

        #expect(collected.values == ["a", "b", "c"])
    }
}

private final class CollectedIDs: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValues: [String] = []

    var values: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedValues
    }

    func append(_ value: String) {
        lock.lock()
        storedValues.append(value)
        lock.unlock()
    }
}
