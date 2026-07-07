import Foundation

/// Abstracts "run this docker CLI command and give me stdout" so the
/// scanner and cleanup engine can be tested with canned output instead of
/// depending on a real Docker installation. Mirrors the DI pattern used
/// throughout JingshanCore (`PathValidating`, `RunningApplicationChecking`,
/// `TrashMoving`).
public protocol DockerCommandRunning: Sendable {
    /// Runs `docker <arguments>` and returns stdout on success. Throws on
    /// non-zero exit, on timeout, or if the process cannot be launched.
    func run(_ arguments: [String], timeout: TimeInterval) async throws -> String
}

public enum DockerCommandError: Error, Equatable, Sendable {
    case timedOut
    case launchFailed(description: String)
    case processFailed(exitCode: Int32, stderr: String)
}

/// Real implementation: shells out to the `docker` binary. Every actual
/// mutation of Docker's state in this app goes through here — nothing else
/// is allowed to touch Docker's data directly.
public struct DockerCLI: DockerCommandRunning {
    public let executablePath: String

    public init(executablePath: String) {
        self.executablePath = executablePath
    }

    public static let defaultSearchPaths: [String] = [
        "/usr/local/bin/docker",
        "/opt/homebrew/bin/docker",
        "/Applications/Docker.app/Contents/Resources/bin/docker",
        NSHomeDirectory() + "/.docker/bin/docker",
    ]

    /// Finds the `docker` binary. GUI apps launched via Finder/LaunchServices
    /// get a minimal `PATH` (no `/usr/local/bin`, no Homebrew prefix), so
    /// this checks known install locations explicitly rather than relying
    /// on `Process` + `PATH` lookup.
    public static func locate(searchPaths: [String] = DockerCLI.defaultSearchPaths, fileManager: FileManager = .default) -> String? {
        searchPaths.first { fileManager.isExecutableFile(atPath: $0) }
    }

    public func run(_ arguments: [String], timeout: TimeInterval = 10) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            let resumeLock = NSLock()
            nonisolated(unsafe) var didResume = false
            let resumeOnce: @Sendable (Result<String, Error>) -> Void = { result in
                resumeLock.lock()
                defer { resumeLock.unlock() }
                guard !didResume else { return }
                didResume = true
                continuation.resume(with: result)
            }

            process.terminationHandler = { finishedProcess in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                if finishedProcess.terminationStatus == 0 {
                    resumeOnce(.success(String(data: outputData, encoding: .utf8) ?? ""))
                } else {
                    let stderrString = String(data: errorData, encoding: .utf8) ?? ""
                    resumeOnce(.failure(DockerCommandError.processFailed(exitCode: finishedProcess.terminationStatus, stderr: stderrString)))
                }
            }

            do {
                try process.run()
            } catch {
                resumeOnce(.failure(DockerCommandError.launchFailed(description: "\(error)")))
                return
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if process.isRunning {
                    process.terminate()
                    resumeOnce(.failure(DockerCommandError.timedOut))
                }
            }
        }
    }
}
