import Foundation
import Testing

@testable import JingshanCore

@Suite("DockerHostDataScanner")
struct DockerHostDataScannerTests {
    /// Builds a fake Docker Desktop data tree under a scratch home dir.
    private func makeFakeDockerHome() throws -> URL {
        let home = try TestFixtures.makeScratchDirectory()
        let fm = FileManager.default

        let vmDir = home.appendingPathComponent("Library/Containers/com.docker.docker/Data/vms/0/data", isDirectory: true)
        try fm.createDirectory(at: vmDir, withIntermediateDirectories: true)
        try TestFixtures.writeFile(at: vmDir.appendingPathComponent("Docker.raw"), contents: String(repeating: "x", count: 5000))

        let logDir = home.appendingPathComponent("Library/Containers/com.docker.docker/Data/log", isDirectory: true)
        try fm.createDirectory(at: logDir, withIntermediateDirectories: true)
        try TestFixtures.writeFile(at: logDir.appendingPathComponent("docker.log"), contents: "log data")

        let cacheDir = home.appendingPathComponent("Library/Caches/Docker Desktop", isDirectory: true)
        try fm.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        try TestFixtures.writeFile(at: cacheDir.appendingPathComponent("cache.bin"), contents: "cache")

        return home
    }

    @Test("when Docker Desktop is quit, the VM disk is offered as a destructive, non-default, Trash-routed filesystem item")
    func vmDiskOfferedWhenDockerQuit() async throws {
        let home = try makeFakeDockerHome()
        defer { TestFixtures.removeIfNeeded(home) }

        let scanner = DockerHostDataScanner(homeDirectory: home.path, dockerDesktopRunning: false)
        let items = await scanner.scan()

        let disk = try #require(items.first { $0.kind == .diskImage })
        #expect(disk.risk == .destructive)
        #expect(!disk.defaultSelected)
        guard case .filesystemPath(let path) = disk.removal else {
            Issue.record("expected filesystemPath removal for the VM disk, got \(disk.removal)")
            return
        }
        #expect(path.hasSuffix("Docker.raw"))
        #expect(disk.sizeBytes == 5000)
    }

    @Test("while Docker Desktop is running, the VM disk is withheld entirely (never touchable)")
    func vmDiskWithheldWhenDockerRunning() async throws {
        let home = try makeFakeDockerHome()
        defer { TestFixtures.removeIfNeeded(home) }

        let scanner = DockerHostDataScanner(homeDirectory: home.path, dockerDesktopRunning: true)
        let items = await scanner.scan()

        #expect(!items.contains { $0.kind == .diskImage })
        // Logs/caches are still safe to offer while Docker runs.
        #expect(items.contains { $0.kind == .appLog })
        #expect(items.contains { $0.kind == .appCache })
    }

    @Test("logs and app caches are safe, default-selected, filesystem-routed items")
    func logsAndCachesAreSafeDefaults() async throws {
        let home = try makeFakeDockerHome()
        defer { TestFixtures.removeIfNeeded(home) }

        let scanner = DockerHostDataScanner(homeDirectory: home.path, dockerDesktopRunning: false)
        let items = await scanner.scan()

        let log = try #require(items.first { $0.kind == .appLog })
        #expect(log.risk == .safe)
        #expect(log.defaultSelected)

        let cache = try #require(items.first { $0.kind == .appCache })
        #expect(cache.risk == .safe)
        #expect(cache.defaultSelected)

        for item in items {
            guard case .filesystemPath = item.removal else {
                Issue.record("host data item \(item.id) must be a filesystemPath, got \(item.removal)")
                return
            }
        }
    }

    @Test("returns nothing when no Docker Desktop data exists")
    func nothingWhenNoDockerData() async throws {
        let home = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(home) }

        let scanner = DockerHostDataScanner(homeDirectory: home.path, dockerDesktopRunning: false)
        let items = await scanner.scan()
        #expect(items.isEmpty)
    }
}
