import Foundation

/// Scans the Docker daemon for cleanup candidates: containers, images
/// (dangling + unused-tagged), aggregate build cache, dangling volumes, and
/// unused custom networks. Needs the daemon running — host-side data (the
/// VM disk, logs) is scanned separately by `DockerHostDataScanner`, which
/// works with Docker stopped.
public struct DockerResourceScanner: Sendable {
    private let commandRunner: DockerCommandRunning

    public init(commandRunner: DockerCommandRunning) {
        self.commandRunner = commandRunner
    }

    public func scanAll() async -> [DockerCleanableItem] {
        // Containers are scanned first and returned first so the UI/engine
        // can remove them before images: an image still referenced by a
        // (stopped) container can't be removed until that container is gone.
        let containers = await scanContainers()
        async let dangling = scanDanglingImages()
        async let unusedTagged = scanUnusedTaggedImages()
        async let buildCache = scanBuildCache()
        async let volumes = scanDanglingVolumes()
        async let networks = scanUnusedNetworks()
        return await containers + dangling + unusedTagged + buildCache + volumes + networks
    }

    public func scanContainers() async -> [DockerCleanableItem] {
        // `-s`/`--size` is required for the `Size` field to actually be
        // computed; without it `docker ps` still emits the key but leaves
        // it empty, which would silently show every container as
        // "size unknown" instead of its real reclaimable size.
        guard let output = try? await commandRunner.run(["ps", "-a", "-s", "--format", "{{json .}}"], timeout: 15) else {
            return []
        }
        return Self.decodeNDJSON(output, as: RawContainer.self).map(Self.classify)
    }

    public func scanDanglingImages() async -> [DockerCleanableItem] {
        guard
            let output = try? await commandRunner.run(
                ["images", "--filter", "dangling=true", "--format", "{{json .}}"],
                timeout: 15
            )
        else {
            return []
        }
        return Self.decodeNDJSON(output, as: RawImage.self).map(Self.classifyDangling)
    }

    /// Tagged images not referenced by any container. This is the main
    /// "unwanted images" the user wants to reclaim (usually far larger than
    /// dangling layers). Marked `.caution` and NOT default-selected:
    /// removing an image means re-pulling or rebuilding it if wanted again,
    /// and a locally-built-never-pushed image can't be recovered without its
    /// Dockerfile + context. Removal uses the scan-time immutable image ID
    /// WITHOUT `-f`, so a retargeted tag cannot redirect the action and Docker
    /// still refuses to remove any image in use.
    public func scanUnusedTaggedImages() async -> [DockerCleanableItem] {
        guard let imagesOutput = try? await commandRunner.run(["images", "--format", "{{json .}}"], timeout: 15) else {
            return []
        }
        let usedReferences = await usedImageReferences()

        var items: [DockerCleanableItem] = []
        var seenReferences = Set<String>()
        for raw in Self.decodeNDJSON(imagesOutput, as: RawImage.self) {
            // Skip dangling images (handled by scanDanglingImages) and any
            // image reference already emitted (docker lists one row per tag).
            guard raw.Repository != "<none>", raw.Tag != "<none>" else { continue }
            let reference = "\(raw.Repository):\(raw.Tag)"
            guard seenReferences.insert(reference).inserted else { continue }
            guard !Self.imageIsUsed(reference: reference, id: raw.ID, usedReferences: usedReferences) else { continue }

            items.append(
                DockerCleanableItem(
                    id: "image:\(reference)",
                    kind: .image,
                    displayName: reference,
                    detail: "未被任何容器使用 · \(raw.CreatedSince)",
                    sizeBytes: DockerSizeParsing.parseLeadingBytes(from: raw.Size),
                    risk: .caution,
                    riskNote: "该镜像当前未被任何容器使用。删除后如需再用要重新拉取或重新构建；本地构建且未推送到仓库的镜像删除后需要凭 Dockerfile 重新构建才能恢复。若镜像其实仍被某容器占用，Docker 会拒绝删除、不会误删。",
                    defaultSelected: false,
                    // Bind removal to the immutable image ID captured during
                    // scanning. A mutable repo:tag can be retargeted while
                    // the confirmation sheet is open; deleting by ID then
                    // fails safely if the old object vanished instead of
                    // touching the newly tagged image.
                    removal: .dockerCommand(arguments: ["rmi", raw.ID])
                )
            )
        }
        return items
    }

    /// Build cache is not enumerable item-by-item the way containers or
    /// images are (BuildKit's cache is an opaque layer graph); Docker's own
    /// tooling treats it as one reclaimable lump too (`docker builder
    /// prune`), so this returns at most one aggregate item.
    public func scanBuildCache() async -> [DockerCleanableItem] {
        guard let output = try? await commandRunner.run(["system", "df", "--format", "{{json .}}"], timeout: 15) else {
            return []
        }
        let rows = Self.decodeNDJSON(output, as: RawDiskUsageRow.self)
        guard let buildCacheRow = rows.first(where: { $0.Type.caseInsensitiveCompare("Build Cache") == .orderedSame }) else {
            return []
        }
        let sizeBytes = DockerSizeParsing.parseLeadingBytes(from: buildCacheRow.Reclaimable)
        if let sizeBytes, sizeBytes == 0 {
            return []
        }
        return [
            DockerCleanableItem(
                id: "buildCache:unused",
                kind: .buildCache,
                displayName: "未使用的构建缓存",
                detail: "BuildKit 构建缓存层（不含当前镜像仍在使用的部分）",
                sizeBytes: sizeBytes,
                risk: .safe,
                riskNote: "只清理未被任何现有镜像引用的构建缓存层，清理后下次构建相关步骤需要重新执行、速度会变慢，但不会丢失任何持久数据，也不影响已有镜像的构建缓存。",
                defaultSelected: true,
                // Deliberately without `-a`: that flag also evicts cache
                // still shared with existing images, which would make
                // their *next* rebuild slower too — a bigger effect than
                // this item's "safe" framing and its size (drawn from
                // `docker system df`'s already-reclaimable figure) imply.
                removal: .dockerCommand(arguments: ["builder", "prune", "-f"])
            )
        ]
    }

    /// Volume sizes are deliberately never computed via the host
    /// filesystem. On macOS, Docker Desktop runs containers (and their
    /// volumes) inside a Linux VM; a volume's `Mountpoint` is a path
    /// *inside that VM*, not a real path on the Mac's filesystem. Passing
    /// it to `FileManager`/`PathValidator` would either fail or — worse —
    /// silently resolve to an unrelated host path. Size stays `nil`
    /// ("unknown") rather than risk that; only the `docker` CLI itself is
    /// ever allowed to touch Docker's actual storage.
    public func scanDanglingVolumes() async -> [DockerCleanableItem] {
        guard
            let output = try? await commandRunner.run(
                ["volume", "ls", "--filter", "dangling=true", "--format", "{{json .}}"],
                timeout: 15
            )
        else {
            return []
        }
        var items: [DockerCleanableItem] = []
        for raw in Self.decodeNDJSON(output, as: RawVolume.self) {
            let identityArguments = ["volume", "inspect", "--format", "{{.CreatedAt}}", raw.Name]
            guard let createdAt = try? await commandRunner.run(identityArguments, timeout: 10),
                  !createdAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { continue }
            items.append(Self.classify(raw, createdAt: createdAt))
        }
        return items
    }

    /// Custom networks not currently attached to any *running* container.
    /// Presented as one aggregate action (like build cache) rather than
    /// enumerated per-network: a network carries no meaningful byte size to
    /// report per item anyway — it is configuration metadata, not data.
    /// Default (bridge/host/none) networks are never touched.
    ///
    /// Tiered `.caution` (not `.safe`) and NOT selected by default — and
    /// this is a *confirmed*, not merely suspected, risk. Verified directly
    /// against a live daemon: a network with a container attached but not
    /// running (`docker create --network X ...`, left in `Created` state,
    /// and separately a container that was `start`ed and stopped) was
    /// deleted by `docker network prune -f` in both cases — Docker's own
    /// "in use" check for network pruning only looks at currently-running
    /// endpoints, not at every container configured to use that network.
    /// So a `docker compose stop`'d (rather than `down`'d) project's network
    /// is genuinely indistinguishable, to `network prune`, from a truly
    /// abandoned one — exactly the same class of "currently unused ≠
    /// abandoned" judgment already used to justify `.caution` for
    /// unused-tagged-images elsewhere in this file. This is why the scanner
    /// does not attempt to re-derive container↔network attachment itself
    /// (that would still miss the stopped-container case) and instead
    /// relies on the tier + confirmation gate to make the risk visible to
    /// the user before they select it.
    public func scanUnusedNetworks() async -> [DockerCleanableItem] {
        guard
            let output = try? await commandRunner.run(
                ["network", "ls", "--filter", "type=custom", "--format", "{{json .}}"],
                timeout: 15
            )
        else {
            return []
        }
        let customNetworks = Self.decodeNDJSON(output, as: RawNetwork.self)
        guard !customNetworks.isEmpty else { return [] }
        return [
            DockerCleanableItem(
                id: "network:unused",
                kind: .network,
                displayName: "未使用的自定义网络",
                detail: "共 \(customNetworks.count) 个自定义网络，清理其中未被任何容器连接的部分",
                sizeBytes: nil,
                risk: .caution,
                riskNote: "只清理未被任何容器连接的自定义网络，仅是网络配置元数据，不占用有意义的磁盘空间；默认的 bridge/host/none 网络不会被清理。如果某个项目只是暂时停止（如 docker compose stop 而非 down），其网络可能仍会被判定为“未使用”而清理掉，下次启动项目时会自动重新创建，但请确认不是临时停用的项目后再清理。",
                defaultSelected: false,
                removal: .dockerCommand(arguments: ["network", "prune", "-f"])
            )
        ]
    }

    // MARK: - Image usage cross-reference

    private func usedImageReferences() async -> Set<String> {
        guard let output = try? await commandRunner.run(["ps", "-a", "--format", "{{json .}}"], timeout: 15) else {
            return []
        }
        return Set(Self.decodeNDJSON(output, as: RawContainer.self).map(\.Image))
    }

    static func imageIsUsed(reference: String, id: String, usedReferences: Set<String>) -> Bool {
        if usedReferences.contains(reference) { return true }
        let normalizedID = id.hasPrefix("sha256:") ? String(id.dropFirst("sha256:".count)) : id
        let shortID = String(normalizedID.prefix(12))
        if usedReferences.contains(normalizedID) || usedReferences.contains(shortID) { return true }
        // A container created directly from an image ID records a truncated
        // ID as its Image field; treat any used ref that is a prefix of this
        // image's ID as a match.
        return usedReferences.contains { !$0.isEmpty && normalizedID.hasPrefix($0) }
    }

    // MARK: - Parsing

    private struct RawContainer: Decodable {
        let ID: String
        let Image: String
        let Names: String
        let State: String
        let Status: String
        let Size: String
    }

    private struct RawImage: Decodable {
        let ID: String
        let Repository: String
        let Tag: String
        let CreatedSince: String
        let Size: String
    }

    private struct RawDiskUsageRow: Decodable {
        let `Type`: String
        let Reclaimable: String
    }

    private struct RawVolume: Decodable {
        let Name: String
        let Driver: String
    }

    private struct RawNetwork: Decodable {
        let ID: String
        let Name: String
        let Driver: String
    }

    private static func decodeNDJSON<T: Decodable>(_ raw: String, as type: T.Type) -> [T] {
        raw.split(separator: "\n").compactMap { line in
            guard let data = line.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(T.self, from: data)
        }
    }

    private static func classify(_ raw: RawContainer) -> DockerCleanableItem {
        let stateLowercased = raw.State.lowercased()
        let isRunning = stateLowercased == "running" || stateLowercased == "paused"
        let sizeBytes = DockerSizeParsing.parseLeadingBytes(from: raw.Size)

        if isRunning {
            return DockerCleanableItem(
                id: "container:\(raw.ID)",
                kind: .container,
                displayName: raw.Names,
                detail: "\(raw.Image) · \(raw.Status)",
                sizeBytes: sizeBytes,
                risk: .destructive,
                riskNote: "该容器正在运行，清理会强制停止并删除；容器内尚未提交到镜像或写入具名卷的更改会永久丢失。",
                defaultSelected: false,
                removal: .dockerCommand(arguments: ["rm", "-f", raw.ID])
            )
        }

        return DockerCleanableItem(
            id: "container:\(raw.ID)",
            kind: .container,
            displayName: raw.Names,
            detail: "\(raw.Image) · \(raw.Status)",
            sizeBytes: sizeBytes,
            risk: .caution,
            riskNote: "已停止的容器，删除后其容器内文件系统的改动（如果没有写入具名卷）会丢失；镜像和卷不受影响，需要时可以重新创建容器。",
            defaultSelected: true,
            removal: .dockerCommand(arguments: ["rm", raw.ID])
        )
    }

    private static func classifyDangling(_ raw: RawImage) -> DockerCleanableItem {
        DockerCleanableItem(
            id: "image:\(raw.ID)",
            kind: .image,
            displayName: "<none>:<none>",
            detail: "悬空镜像 · \(raw.CreatedSince)",
            sizeBytes: DockerSizeParsing.parseLeadingBytes(from: raw.Size),
            risk: .safe,
            riskNote: "无标签的悬空镜像，是构建过程中残留的中间层，未被任何容器或标签引用，可以安全删除。",
            defaultSelected: true,
            removal: .dockerCommand(arguments: ["rmi", raw.ID])
        )
    }

    private static func classify(_ raw: RawVolume, createdAt: String) -> DockerCleanableItem {
        DockerCleanableItem(
            id: "volume:\(raw.Name)",
            kind: .volume,
            displayName: raw.Name,
            detail: "未被任何容器使用的数据卷（\(raw.Driver)）",
            sizeBytes: nil,
            risk: .destructive,
            riskNote: "数据卷可能包含数据库或应用的持久化数据。删除后数据永久丢失且无法恢复，请确认卷内数据不再需要后再清理。",
            defaultSelected: false,
            removal: .verifiedDockerCommand(
                preflightArguments: ["volume", "inspect", "--format", "{{.CreatedAt}}", raw.Name],
                expectedOutput: createdAt.trimmingCharacters(in: .whitespacesAndNewlines),
                arguments: ["volume", "rm", raw.Name]
            )
        )
    }
}
