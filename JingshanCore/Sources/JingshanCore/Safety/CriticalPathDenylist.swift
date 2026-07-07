import Foundation

/// Hard floor of system paths JingshanCore will never delete, regardless of
/// user whitelist or override flags. Data lives in a bundled JSON resource
/// (`CriticalPathDenylist.json`) so the rule set stays separate from the
/// matching logic here, mirroring Mole's split between `app_protection.sh`
/// (logic) and `app_protection_data.sh` (data).
public struct CriticalPathDenylist: Sendable {
    public struct Rule: Codable, Equatable, Sendable {
        public let pathPrefix: String
        public let matchType: MatchType
        public let reason: String

        public init(pathPrefix: String, matchType: MatchType, reason: String) {
            self.pathPrefix = pathPrefix
            self.matchType = matchType
            self.reason = reason
        }
    }

    public enum MatchType: String, Codable, Sendable {
        /// The resolved path must equal this rule exactly (e.g. `/Applications` itself,
        /// not its contents).
        case exactPath
        /// The resolved path must equal this rule, or be nested underneath it.
        case prefixOfDirectory
    }

    public let rules: [Rule]

    public init(rules: [Rule]) {
        self.rules = rules
    }

    public static let `default`: CriticalPathDenylist = {
        loadBundled() ?? CriticalPathDenylist(rules: fallbackRules)
    }()

    /// Returns the first rule matching `path`. Comparison is case-insensitive
    /// because the default macOS volume format is case-insensitive-but-preserving;
    /// a denylist is safer over-matching than under-matching on that boundary.
    public func firstMatch(forResolvedPath path: String) -> Rule? {
        let normalized = PathValidator.normalize(path).lowercased()
        for rule in rules {
            let rulePath = PathValidator.normalize(rule.pathPrefix).lowercased()
            switch rule.matchType {
            case .exactPath:
                if normalized == rulePath {
                    return rule
                }
            case .prefixOfDirectory:
                if normalized == rulePath || normalized.hasPrefix(rulePath + "/") {
                    return rule
                }
            }
        }
        return nil
    }

    private static func loadBundled() -> CriticalPathDenylist? {
        guard let url = Bundle.module.url(forResource: "CriticalPathDenylist", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let rules = try? JSONDecoder().decode([Rule].self, from: data)
        else {
            return nil
        }
        return CriticalPathDenylist(rules: rules)
    }

    /// Used only if the bundled JSON resource fails to load (e.g. a stripped
    /// build). Deliberately fails closed: same rule set as the JSON, kept in
    /// sync by hand since it exists purely as a last-resort safety net.
    static let fallbackRules: [Rule] = [
        Rule(pathPrefix: "/", matchType: .exactPath, reason: "文件系统根目录"),
        Rule(pathPrefix: "/System", matchType: .prefixOfDirectory, reason: "macOS 系统只读卷"),
        Rule(pathPrefix: "/Library/Apple", matchType: .prefixOfDirectory, reason: "Apple 系统组件"),
        Rule(pathPrefix: "/Library/Keychains", matchType: .prefixOfDirectory, reason: "系统钥匙串"),
        Rule(pathPrefix: "/Library/Extensions", matchType: .prefixOfDirectory, reason: "系统内核扩展"),
        Rule(pathPrefix: "/private", matchType: .prefixOfDirectory, reason: "系统私有目录（含 /etc, /var, /tmp 解析后的真实路径）"),
        Rule(pathPrefix: "/etc", matchType: .prefixOfDirectory, reason: "系统配置（符号链接到 /private/etc）"),
        Rule(pathPrefix: "/var", matchType: .prefixOfDirectory, reason: "系统运行时数据（符号链接到 /private/var）"),
        Rule(pathPrefix: "/tmp", matchType: .prefixOfDirectory, reason: "系统临时目录（符号链接到 /private/tmp）"),
        Rule(pathPrefix: "/bin", matchType: .prefixOfDirectory, reason: "系统二进制"),
        Rule(pathPrefix: "/sbin", matchType: .prefixOfDirectory, reason: "系统管理二进制"),
        Rule(pathPrefix: "/usr/bin", matchType: .prefixOfDirectory, reason: "系统二进制"),
        Rule(pathPrefix: "/usr/sbin", matchType: .prefixOfDirectory, reason: "系统管理二进制"),
        Rule(pathPrefix: "/usr/lib", matchType: .prefixOfDirectory, reason: "系统库"),
        Rule(pathPrefix: "/usr/libexec", matchType: .prefixOfDirectory, reason: "系统辅助程序"),
        Rule(pathPrefix: "/usr/share", matchType: .prefixOfDirectory, reason: "系统共享资源"),
        Rule(pathPrefix: "/usr/standalone", matchType: .prefixOfDirectory, reason: "系统独立组件"),
        Rule(pathPrefix: "/Applications", matchType: .exactPath, reason: "应用目录本身（个别 App 由卸载器模块处理）"),
        Rule(pathPrefix: "/Volumes", matchType: .exactPath, reason: "外部卷挂载根目录本身"),
    ]
}
