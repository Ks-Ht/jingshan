import Foundation

@testable import JingshanCore

final class InMemoryOperationLogger: OperationLogging, @unchecked Sendable {
    private let lock = NSLock()
    private var storedEntries: [OperationLogEntry] = []

    var entries: [OperationLogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return storedEntries
    }

    func log(_ entry: OperationLogEntry) {
        lock.lock()
        storedEntries.append(entry)
        lock.unlock()
    }
}

final class FakeRunningApplicationChecker: RunningApplicationChecking, @unchecked Sendable {
    private let lock = NSLock()
    private var runningBundleIdentifiers: Set<String>

    init(runningBundleIdentifiers: Set<String> = []) {
        self.runningBundleIdentifiers = runningBundleIdentifiers
    }

    func isApplicationRunning(bundleIdentifier: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return runningBundleIdentifiers.contains(bundleIdentifier)
    }
}

/// Redirects Trash moves to a throwaway directory so tests never touch the
/// real `~/.Trash`.
final class FakeTrashMover: TrashMoving, @unchecked Sendable {
    let trashDirectory: URL

    init(trashDirectory: URL) {
        self.trashDirectory = trashDirectory
        try? FileManager.default.createDirectory(at: trashDirectory, withIntermediateDirectories: true)
    }

    func moveToTrash(_ url: URL) throws -> URL? {
        let destination = trashDirectory.appendingPathComponent(url.lastPathComponent)
        try FileManager.default.moveItem(at: url, to: destination)
        return destination
    }
}
