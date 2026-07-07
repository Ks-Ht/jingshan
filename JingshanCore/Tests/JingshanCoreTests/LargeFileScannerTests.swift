import Foundation
import Testing

@testable import JingshanCore

@Suite("LargeFileScanner")
struct LargeFileScannerTests {
    @Test("finds files at or above the size threshold, sorted largest-first, and skips small ones")
    func findsLargeFilesSorted() async throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }

        try Data(count: 200_000).write(to: scratch.appendingPathComponent("big.bin"))
        try Data(count: 500_000).write(to: scratch.appendingPathComponent("bigger.bin"))
        try Data(count: 100).write(to: scratch.appendingPathComponent("small.bin"))

        // Low threshold (100 KB) so the test doesn't need hundreds of MB, but
        // still well above one filesystem block so the tiny file is excluded
        // even after block-rounding of its allocated size.
        let scanner = LargeFileScanner(minBytes: 100_000)
        let results = await scanner.scan(root: scratch.path)

        let names = results.map(\.displayName)
        #expect(names.contains("big.bin"))
        #expect(names.contains("bigger.bin"))
        #expect(!names.contains("small.bin")) // below threshold
        // Largest first.
        #expect(results.first?.displayName == "bigger.bin")
    }
}
