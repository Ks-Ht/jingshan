import Foundation

/// Creates fixture directories under the real home directory (never under
/// system temp, which resolves to `/private/var/folders/...` and would
/// collide with the critical-path denylist) so tests exercise the same
/// filesystem region the v1 Clean module actually targets.
enum TestFixtures {
    static func makeScratchDirectory() throws -> URL {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".jingshan-core-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func writeFile(at url: URL, contents: String = "jingshan-test-fixture") throws {
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    static func removeIfNeeded(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
