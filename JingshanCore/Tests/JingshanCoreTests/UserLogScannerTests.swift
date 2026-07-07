import Foundation
import Testing

@testable import JingshanCore

@Suite("UserLogScanner")
struct UserLogScannerTests {
    @Test("lists log subfolders but excludes Jingshan's own log directory")
    func excludesOwnLogDirectory() async throws {
        let scratch = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(scratch) }

        let someAppLogs = scratch.appendingPathComponent("SomeApp", isDirectory: true)
        try FileManager.default.createDirectory(at: someAppLogs, withIntermediateDirectories: true)
        let ownLogs = scratch.appendingPathComponent("Jingshan", isDirectory: true)
        try FileManager.default.createDirectory(at: ownLogs, withIntermediateDirectories: true)

        let scanner = UserLogScanner(directoryPath: scratch.path)
        let category = await scanner.scan()

        #expect(category.items.count == 1)
        #expect(category.items.first?.path == someAppLogs.path)
    }
}
