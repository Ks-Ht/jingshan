import Foundation

/// Scans Docker Desktop's real on-disk data on the Mac host — the stuff
/// that keeps taking space even when the daemon is stopped. Every path here
/// is a genuine macOS path (verified to exist before it is offered), so
/// removal routes through the audited `DeletionEngine` (path validation,
/// protected-path checks, Trash routing, logging) rather than the docker
/// CLI.
///
/// This is intentionally NOT a full sweep of `~/.docker`: that directory
/// mixes reclaimable caches with must-keep config, registry credentials
/// (`config.json`), daemon settings (`daemon.json`), and context
/// definitions (`contexts/`). Deleting it wholesale would log the user out
/// of registries and drop their custom contexts, so it is left untouched.
public struct DockerHostDataScanner: Sendable {
    private let homeDirectory: String
    /// When Docker Desktop is running, the VM disk is in active use and
    /// must not be touched (moving/deleting it would corrupt the running
    /// VM). The scanner still reports its size for visibility but marks it
    /// non-removable in that state.
    private let dockerDesktopRunning: Bool

    public init(homeDirectory: String = NSHomeDirectory(), dockerDesktopRunning: Bool) {
        self.homeDirectory = homeDirectory
        self.dockerDesktopRunning = dockerDesktopRunning
    }

    public func scan() async -> [DockerCleanableItem] {
        var items: [DockerCleanableItem] = []
        if let disk = await scanVMDiskImage() { items.append(disk) }
        if let log = await scanLogs() { items.append(log) }
        items.append(contentsOf: await scanAppCaches())
        return items
    }

    /// The single VM disk image file that backs the entire Docker data
    /// store (all images, containers, volumes, build cache). Reclaiming it
    /// is a full factory reset of Docker. Destructive, never default-
    /// selected, routed to Trash by the engine (so a reset can still be
    /// undone). Only offered when Docker Desktop is fully quit — while it
    /// runs the VM disk is in active use and touching it would corrupt the
    /// running VM, so the item is withheld entirely (the UI shows a hint to
    /// quit Docker first). When quit, it is the single most destructive
    /// action in the whole app, hence the strong note.
    func scanVMDiskImage() async -> DockerCleanableItem? {
        guard !dockerDesktopRunning else { return nil }
        let dataRoot = homeDirectory + "/Library/Containers/com.docker.docker/Data"
        let candidates = [
            dataRoot + "/vms/0/data/Docker.raw",
            dataRoot + "/vms/0/Docker.raw",
            dataRoot + "/vms/0/data/Docker.qcow2",
            dataRoot + "/vms/0/Docker.qcow2",
        ]
        guard let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            return nil
        }
        let size = await FileSizeCalculator.sizeAsync(ofPath: path)

        return DockerCleanableItem(
            id: "hostDiskImage:\(path)",
            kind: .diskImage,
            displayName: "Docker 虚拟磁盘（全部数据）",
            detail: path,
            sizeBytes: size,
            risk: .destructive,
            riskNote: "这是 Docker 的整个数据存储，所有镜像、容器、数据卷、构建缓存都在里面。清理相当于把 Docker 恢复出厂设置，全部内容一并清空——数据卷里的数据库等持久化数据也会丢失。会先移动到废纸篓，必要时可从废纸篓恢复。",
            defaultSelected: false,
            removal: .filesystemPath(path)
        )
    }

    func scanLogs() async -> DockerCleanableItem? {
        let path = homeDirectory + "/Library/Containers/com.docker.docker/Data/log"
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let size = await FileSizeCalculator.sizeAsync(ofPath: path)
        if let size, size == 0 { return nil }
        return DockerCleanableItem(
            id: "hostLog:\(path)",
            kind: .appLog,
            displayName: "Docker Desktop 日志",
            detail: path,
            sizeBytes: size,
            risk: .safe,
            riskNote: "Docker Desktop 的运行日志，清理不影响任何镜像、容器或数据。",
            defaultSelected: true,
            removal: .filesystemPath(path)
        )
    }

    func scanAppCaches() async -> [DockerCleanableItem] {
        let candidates = [
            homeDirectory + "/Library/Caches/com.docker.docker",
            homeDirectory + "/Library/Caches/Docker Desktop",
        ]
        var items: [DockerCleanableItem] = []
        for path in candidates {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let size = await FileSizeCalculator.sizeAsync(ofPath: path)
            if let size, size == 0 { continue }
            items.append(
                DockerCleanableItem(
                    id: "hostCache:\(path)",
                    kind: .appCache,
                    displayName: "Docker Desktop 缓存",
                    detail: path,
                    sizeBytes: size,
                    risk: .safe,
                    riskNote: "Docker Desktop 的应用缓存，清理后会自动重新生成，不影响镜像、容器或数据。",
                    defaultSelected: true,
                    removal: .filesystemPath(path)
                )
            )
        }
        return items
    }
}
