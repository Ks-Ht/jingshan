import Foundation

/// Real-world grouping shown to the user, distinct from which scanner
/// happened to find an item. A user does not think in terms of "userCaches
/// scanner" — they think "this is a dev tool cache" or "this is my chat
/// app's cache". Mirrors the grouping Mole's own Mac app uses.
public enum CacheGroup: String, CaseIterable, Sendable, Codable {
    case appCache
    case devTools
    case aiTools
    case browser
    case communication
    case other
    case trash

    public var displayName: String {
        switch self {
        case .appCache: return "App 缓存"
        case .devTools: return "开发工具"
        case .aiTools: return "AI 工具"
        case .browser: return "浏览器"
        case .communication: return "通信工具"
        case .other: return "其他"
        case .trash: return "废纸篓"
        }
    }

    public var groupDescription: String {
        switch self {
        case .appCache: return "应用临时文件，下次启动会重新生成"
        case .devTools: return "Xcode / SwiftPM / Homebrew / npm 等开发工具缓存，重新构建时会自动生成"
        case .aiTools: return "AI 工具的临时缓存，对话记录和项目文件不受影响"
        case .browser: return "浏览器缓存，登录状态和历史记录会保留"
        case .communication: return "聊天软件缓存，可能包含尚未备份的图片和文件，请确认后再清理"
        case .other: return "系统组件或未识别来源的缓存"
        case .trash: return "永久清空废纸篓"
        }
    }

    public var systemImage: String {
        switch self {
        case .appCache: return "app.badge"
        case .devTools: return "hammer"
        case .aiTools: return "sparkles"
        case .browser: return "globe"
        case .communication: return "message"
        case .other: return "shippingbox"
        case .trash: return "trash"
        }
    }

    /// Whether items in this group are selected by default after a scan.
    /// Only the groups a user would confidently recognize and expect to
    /// clean routinely default on: general app caches, dev tool build
    /// caches (the most common, highest-value, fully regenerable target),
    /// and browser caches. Communication apps default off because their
    /// caches often hold media or session state that is not backed up
    /// anywhere else; AI tools and the "other"/unclassified catch-all
    /// default off too — both are lower-confidence buckets (AI tool cache
    /// layout varies and changes often; "other" is by definition whatever
    /// didn't match a more specific rule) where a cautious default is more
    /// appropriate than assuming every user wants them gone unreviewed.
    public var defaultSelected: Bool {
        switch self {
        case .appCache, .devTools, .browser: return true
        case .aiTools, .communication, .other, .trash: return false
        }
    }
}
