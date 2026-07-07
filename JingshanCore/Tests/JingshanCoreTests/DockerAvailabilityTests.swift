import Foundation
import Testing

@testable import JingshanCore

@Suite("DockerAvailability")
struct DockerAvailabilityTests {
    @Test("reports notInstalled when no command runner is available")
    func reportsNotInstalledWhenNoRunner() async {
        let availability = DockerAvailability(commandRunner: nil)
        #expect(await availability.checkStatus() == .notInstalled)
    }

    @Test("reports available when docker info succeeds")
    func reportsAvailableWhenInfoSucceeds() async {
        let runner = FakeDockerCommandRunner()
        runner.setSuccess(for: ["info", "--format", "{{json .}}"], output: "{}")
        let availability = DockerAvailability(commandRunner: runner)
        #expect(await availability.checkStatus() == .available)
    }

    @Test("reports daemonNotRunning when docker info fails")
    func reportsDaemonNotRunningWhenInfoFails() async {
        let runner = FakeDockerCommandRunner()
        runner.setFailure(for: ["info", "--format", "{{json .}}"], error: DockerCommandError.timedOut)
        let availability = DockerAvailability(commandRunner: runner)
        #expect(await availability.checkStatus() == .daemonNotRunning)
    }
}
