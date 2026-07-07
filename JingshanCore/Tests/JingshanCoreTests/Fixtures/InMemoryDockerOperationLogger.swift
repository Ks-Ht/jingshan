import Foundation

@testable import JingshanCore

final class InMemoryDockerOperationLogger: DockerOperationLogging, @unchecked Sendable {
    private let lock = NSLock()
    private var storedEntries: [DockerOperationLogEntry] = []

    var entries: [DockerOperationLogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return storedEntries
    }

    func log(_ entry: DockerOperationLogEntry) {
        lock.lock()
        storedEntries.append(entry)
        lock.unlock()
    }
}
