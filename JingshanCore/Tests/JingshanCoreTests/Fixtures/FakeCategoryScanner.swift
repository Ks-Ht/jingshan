import Foundation

@testable import JingshanCore

struct FakeCategoryScanner: CategoryScanning {
    let categoryID: String
    let displayName: String
    let items: [ScannableItem]

    init(categoryID: String, displayName: String = "fake", items: [ScannableItem] = []) {
        self.categoryID = categoryID
        self.displayName = displayName
        self.items = items
    }

    func scan() async -> ScanCategory {
        ScanCategory(id: categoryID, displayName: displayName, items: items)
    }
}
