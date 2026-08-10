import Foundation

/// How risky it is to remove this resource. Drives both the default
/// selection state and how strongly the UI warns before letting it happen.
public enum DockerRiskLevel: String, Sendable, Codable, CaseIterable {
    /// No realistic downside: dangling images, build cache, logs. Docker
    /// itself considers these orphaned/purely-derived data.
    case safe
    /// Routine cleanup with a small, usually-acceptable downside (a stopped
    /// container's uncommitted writable-layer changes are lost; an unused
    /// image must be re-pulled or rebuilt if wanted again). Not data loss
    /// in the persistent sense.
    case caution
    /// Real, possibly-irreversible data loss: running containers (force
    /// killed), volumes (persistent data with no other copy), and the whole
    /// VM disk image (every image/container/volume at once). Never selected
    /// by default; the UI requires an explicit acknowledgment.
    case destructive

    public var isDefaultSelectable: Bool {
        self != .destructive
    }
}

public enum DockerResourceKind: String, Sendable, Codable, CaseIterable {
    // Runtime resources — removed through the docker CLI (needs the daemon).
    case container
    case image
    case buildCache
    case volume
    case network
    // Host-side data — real macOS files, removed through the audited
    // DeletionEngine (works with the daemon stopped).
    case diskImage
    case appLog
    case appCache

    public var displayName: String {
        switch self {
        case .container: return "容器"
        case .image: return "镜像"
        case .buildCache: return "构建缓存"
        case .volume: return "数据卷"
        case .network: return "网络"
        case .diskImage: return "虚拟磁盘"
        case .appLog: return "日志"
        case .appCache: return "应用缓存"
        }
    }

    public var systemImage: String {
        switch self {
        case .container: return "shippingbox"
        case .image: return "square.stack.3d.down.right"
        case .buildCache: return "hammer"
        case .volume: return "externaldrive"
        case .network: return "network"
        case .diskImage: return "internaldrive"
        case .appLog: return "doc.text"
        case .appCache: return "trash"
        }
    }

    /// Runtime resources need the daemon; host-side data does not. Drives
    /// which section of the Docker screen an item appears in.
    public var isHostSide: Bool {
        switch self {
        case .container, .image, .buildCache, .volume, .network:
            return false
        case .diskImage, .appLog, .appCache:
            return true
        }
    }
}

/// How a `DockerCleanableItem` is actually removed. The two mechanisms are
/// kept type-level distinct so the safety boundary is impossible to blur:
/// docker resources go through the CLI, host files go through the audited
/// `DeletionEngine`. A `.filesystemPath` is ALWAYS a real macOS path (the
/// VM disk image file, a log dir, an app cache) — never a Docker
/// VM-internal path such as a volume Mountpoint.
public enum DockerRemovalMethod: Sendable, Equatable {
    case dockerCommand(arguments: [String])
    /// A mutable Docker name must still identify the exact object seen
    /// during scanning immediately before removal.
    case verifiedDockerCommand(preflightArguments: [String], expectedOutput: String, arguments: [String])
    case filesystemPath(String)

    /// A stable, human-readable description of the action for the audit log.
    public var auditDescription: [String] {
        switch self {
        case .dockerCommand(let arguments):
            return ["docker"] + arguments
        case .verifiedDockerCommand(let preflightArguments, let expectedOutput, let arguments):
            return ["docker-verify"] + preflightArguments + ["expected=\(expectedOutput)", "then", "docker"] + arguments
        case .filesystemPath(let path):
            return ["trash-file", path]
        }
    }
}

/// One Docker-related item the user can choose to remove. The removal
/// mechanism is decided at scan time (the scanner knows the right command
/// or the right host path for each item) and executed verbatim by
/// `DockerCleanupEngine`, which never itself decides how anything is removed.
public struct DockerCleanableItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let kind: DockerResourceKind
    public let displayName: String
    public let detail: String
    public let sizeBytes: Int64?
    public let risk: DockerRiskLevel
    public let riskNote: String
    public let defaultSelected: Bool
    public let removal: DockerRemovalMethod

    public init(
        id: String,
        kind: DockerResourceKind,
        displayName: String,
        detail: String,
        sizeBytes: Int64?,
        risk: DockerRiskLevel,
        riskNote: String,
        defaultSelected: Bool,
        removal: DockerRemovalMethod
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.detail = detail
        self.sizeBytes = sizeBytes
        self.risk = risk
        self.riskNote = riskNote
        self.defaultSelected = defaultSelected
        self.removal = removal
    }
}
