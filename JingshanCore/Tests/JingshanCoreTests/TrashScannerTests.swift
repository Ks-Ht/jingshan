import Foundation
import Testing

@testable import JingshanCore

@Suite("TrashScanner")
struct TrashScannerTests {
    @Test("reports the whole Trash as a single aggregate item")
    func reportsSingleAggregateItem() async throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }

        let trash = scratch.appendingPathComponent("Trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        try TestFixtures.writeFile(at: trash.appendingPathComponent("deleted-file.txt"), contents: "0123456789")

        let scanner = TrashScanner(trashPath: trash.path)
        let category = await scanner.scan()

        #expect(category.items.count == 1)
        // Actual on-disk allocation (block-rounded), not logical bytes.
        #expect(category.items.first?.sizeBytes == FileSizeCalculator.allocatedSize(ofPath: trash.appendingPathComponent("deleted-file.txt").path))
        #expect(category.items.first?.resolvedDisplayLabel == "废纸篓")
    }

    @Test("reports an empty category when Trash does not exist")
    func emptyWhenMissing() async throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }
        let missingTrash = scratch.appendingPathComponent("NoTrashHere").path

        let scanner = TrashScanner(trashPath: missingTrash)
        let category = await scanner.scan()

        #expect(category.items.isEmpty)
    }
}
