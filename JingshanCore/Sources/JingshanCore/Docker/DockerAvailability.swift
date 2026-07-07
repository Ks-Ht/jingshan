import AppKit
import Foundation

public enum DockerAvailabilityStatus: Equatable, Sendable {
    /// The `docker` CLI binary was not found in any known install location.
    case notInstalled
    /// The CLI exists but the daemon did not respond (Docker Desktop not
    /// running, still starting up, or the VM is unhealthy).
    case daemonNotRunning
    case available
}

public struct DockerAvailability: Sendable {
    private let commandRunner: DockerCommandRunning?

    public init(commandRunner: DockerCommandRunning?) {
        self.commandRunner = commandRunner
    }

    public static func makeDefault() -> DockerAvailability {
        guard let path = DockerCLI.locate() else {
            return DockerAvailability(commandRunner: nil)
        }
        return DockerAvailability(commandRunner: DockerCLI(executablePath: path))
    }

    public var isInstalled: Bool {
        commandRunner != nil
    }

    public func checkStatus() async -> DockerAvailabilityStatus {
        guard let commandRunner else { return .notInstalled }
        do {
            _ = try await commandRunner.run(["info", "--format", "{{json .}}"], timeout: 5)
            return .available
        } catch {
            return .daemonNotRunning
        }
    }

    /// Whether the Docker Desktop app is currently running. Used to gate the
    /// host-side VM disk reclaim: that file must not be touched while the VM
    /// backed by it is live. Checked via the app's bundle identifier so a
    /// merely-installed-but-quit Docker Desktop reads as not running.
    @MainActor
    public static func isDockerDesktopRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.docker.docker" }
    }

    /// Launches Docker Desktop (used by the "start Docker" affordance when
    /// the daemon is down but the user wants granular cleanup). Best-effort:
    /// returns whether the launch request was accepted, not whether the
    /// daemon has finished coming up — the caller polls `checkStatus()`.
    @MainActor
    @discardableResult
    public static func launchDockerDesktop() -> Bool {
        let candidates = [
            "/Applications/Docker.app",
            NSHomeDirectory() + "/Applications/Docker.app",
        ]
        guard let appPath = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            return false
        }
        let url = URL(fileURLWithPath: appPath)
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        return true
    }
}
