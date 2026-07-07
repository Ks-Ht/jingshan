import Foundation

@testable import JingshanCore

final class FakeDockerCommandRunner: DockerCommandRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [String: Result<String, Error>] = [:]
    private var storedInvocations: [[String]] = []

    var invokedArguments: [[String]] {
        lock.lock()
        defer { lock.unlock() }
        return storedInvocations
    }

    func setSuccess(for arguments: [String], output: String) {
        lock.lock()
        responses[Self.key(for: arguments)] = .success(output)
        lock.unlock()
    }

    func setFailure(for arguments: [String], error: Error) {
        lock.lock()
        responses[Self.key(for: arguments)] = .failure(error)
        lock.unlock()
    }

    func run(_ arguments: [String], timeout: TimeInterval) async throws -> String {
        guard let result = recordAndLookUp(arguments) else {
            throw DockerCommandError.launchFailed(description: "no canned response for \(arguments)")
        }
        return try result.get()
    }

    // `NSLock.lock()`/`unlock()` are unavailable directly inside an `async`
    // function body under this SDK's concurrency checking; wrapping the
    // critical section in a plain synchronous method sidesteps that.
    private func recordAndLookUp(_ arguments: [String]) -> Result<String, Error>? {
        lock.lock()
        defer { lock.unlock() }
        storedInvocations.append(arguments)
        return responses[Self.key(for: arguments)]
    }

    private static func key(for arguments: [String]) -> String {
        arguments.joined(separator: " ")
    }
}
