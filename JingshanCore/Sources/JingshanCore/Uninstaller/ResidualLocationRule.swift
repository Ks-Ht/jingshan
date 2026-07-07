import Foundation

/// How risky it is to remove a residual location. Mirrors `DockerRiskLevel`'s
/// three-tier vocabulary so the whole app uses one consistent risk language.
public enum ResidualRiskTier: String, Sendable, Equatable, CaseIterable {
    /// Purely regenerated data (caches, logs, saved window state). No
    /// realistic downside.
    case safe
    /// Real user configuration or account state. Losing it just means
    /// reconfiguring the app after a reinstall — not data loss in the
    /// persistent sense.
    case caution
    /// May hold the app's actual working data rather than mere cache or
    /// settings. Never selected by default; the UI requires an explicit
    /// acknowledgment before it can be included.
    case destructive

    /// Only `.safe` residuals are pre-checked after a scan. `.caution` items
    /// (preferences, account/login state) are real configuration a user may
    /// still want if they reinstall — worth offering, not worth assuming
    /// they want gone unreviewed. Matches the same "only the most common,
    /// most confidently-safe items default on" policy applied to Clean's
    /// cache groups.
    public var isDefaultSelectable: Bool { self == .safe }
}

/// A template for one place an app might leave files behind, expressed
/// relative to the user's home directory. Matching is deliberately just an
/// existence check against a computed path — no fuzzy/partial name
/// matching — so a rule can only ever hit the one location it names for the
/// one app being uninstalled.
public struct ResidualLocationRule: Sendable, Equatable {
    /// What identifies the app at this location: most locations are keyed
    /// by bundle identifier (the OS's own convention), but a few
    /// long-standing macOS conventions (Application Support, Logs) key by
    /// the app's human-readable name instead.
    public enum MatchKey: Sendable, Equatable {
        case bundleIdentifier
        case displayName
    }

    public let relativeDirectory: String
    public let matchKey: MatchKey
    public let pathSuffix: String
    public let displayLabel: String
    public let tier: ResidualRiskTier
    public let riskNote: String

    public init(
        relativeDirectory: String,
        matchKey: MatchKey,
        pathSuffix: String = "",
        displayLabel: String,
        tier: ResidualRiskTier,
        riskNote: String
    ) {
        self.relativeDirectory = relativeDirectory
        self.matchKey = matchKey
        self.pathSuffix = pathSuffix
        self.displayLabel = displayLabel
        self.tier = tier
        self.riskNote = riskNote
    }

    public func expectedPath(for app: InstalledApplication, homeDirectory: String) -> String {
        let key = matchKey == .bundleIdentifier ? app.bundleIdentifier : app.displayName
        return "\(homeDirectory)/\(relativeDirectory)/\(key)\(pathSuffix)"
    }

    public static let defaultRules: [ResidualLocationRule] = [
        ResidualLocationRule(
            relativeDirectory: "Library/Caches",
            matchKey: .bundleIdentifier,
            displayLabel: "缓存",
            tier: .safe,
            riskNote: "可安全删除，应用下次运行时会自动重建。"
        ),
        ResidualLocationRule(
            relativeDirectory: "Library/WebKit",
            matchKey: .bundleIdentifier,
            displayLabel: "WebKit 数据",
            tier: .safe,
            riskNote: "应用内嵌网页视图产生的数据，可安全删除。"
        ),
        ResidualLocationRule(
            relativeDirectory: "Library/HTTPStorages",
            matchKey: .bundleIdentifier,
            displayLabel: "网络缓存",
            tier: .safe,
            riskNote: "网络请求缓存，可安全删除。"
        ),
        ResidualLocationRule(
            relativeDirectory: "Library/Saved Application State",
            matchKey: .bundleIdentifier,
            pathSuffix: ".savedState",
            displayLabel: "窗口状态",
            tier: .safe,
            riskNote: "用于恢复上次退出时的窗口布局，可安全删除。"
        ),
        ResidualLocationRule(
            relativeDirectory: "Library/Logs",
            matchKey: .displayName,
            displayLabel: "日志",
            tier: .safe,
            riskNote: "运行日志，可安全删除。"
        ),
        ResidualLocationRule(
            relativeDirectory: "Library/Preferences",
            matchKey: .bundleIdentifier,
            pathSuffix: ".plist",
            displayLabel: "偏好设置",
            tier: .caution,
            riskNote: "包含应用的个性化设置，删除后重新安装需要重新配置。"
        ),
        ResidualLocationRule(
            relativeDirectory: "Library/Application Support",
            matchKey: .bundleIdentifier,
            displayLabel: "支持文件",
            tier: .caution,
            riskNote: "可能包含账号登录状态、插件或用户数据，删除后需要重新设置。"
        ),
        ResidualLocationRule(
            relativeDirectory: "Library/Application Support",
            matchKey: .displayName,
            displayLabel: "支持文件",
            tier: .caution,
            riskNote: "可能包含账号登录状态、插件或用户数据，删除后需要重新设置。"
        ),
        ResidualLocationRule(
            relativeDirectory: "Library/Containers",
            matchKey: .bundleIdentifier,
            displayLabel: "沙盒容器数据",
            tier: .destructive,
            riskNote: "可能存放应用的实际数据而非仅缓存——部分应用（例如虚拟化/容器类工具）会在这里保存数 GB 到数十 GB 的核心数据。请确认这里没有你还需要的数据后再清理，默认不勾选。"
        ),
    ]
}
