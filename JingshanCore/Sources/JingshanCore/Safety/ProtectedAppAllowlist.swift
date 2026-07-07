import Foundation

/// Bundle identifiers that are always off-limits as cleanup targets,
/// independent of whether the app is currently running. This is distinct
/// from the *running-app* check in `DeletionEngine`, which is dynamic and
/// overridable; entries here are a static, non-overridable floor (e.g. core
/// Apple system bundle identifiers), mirroring the intent of Mole's
/// `app_protection.sh` category lists.
public struct ProtectedAppAllowlist: Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        /// Supports a single trailing/embedded `*` wildcard, e.g. "com.apple.*".
        public let bundleIdentifierPattern: String
        public let reason: String

        public init(bundleIdentifierPattern: String, reason: String) {
            self.bundleIdentifierPattern = bundleIdentifierPattern
            self.reason = reason
        }
    }

    public let entries: [Entry]

    public init(entries: [Entry]) {
        self.entries = entries
    }

    public static let `default`: ProtectedAppAllowlist = {
        loadBundled() ?? ProtectedAppAllowlist(entries: fallbackEntries)
    }()

    public func isProtected(bundleIdentifier: String) -> Bool {
        entries.contains { matches(pattern: $0.bundleIdentifierPattern, value: bundleIdentifier) }
    }

    private func matches(pattern: String, value: String) -> Bool {
        guard pattern.contains("*") else {
            return pattern.caseInsensitiveCompare(value) == .orderedSame
        }
        let escaped = NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*")
        guard let regex = try? NSRegularExpression(pattern: "^\(escaped)$", options: [.caseInsensitive]) else {
            return false
        }
        let range = NSRange(value.startIndex..., in: value)
        return regex.firstMatch(in: value, range: range) != nil
    }

    private static func loadBundled() -> ProtectedAppAllowlist? {
        guard let url = Bundle.module.url(forResource: "ProtectedAppAllowlist", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else {
            return nil
        }
        return ProtectedAppAllowlist(entries: entries)
    }

    static let fallbackEntries: [Entry] = [
        Entry(bundleIdentifierPattern: "com.apple.*", reason: "Apple 系统应用，禁止作为清理目标"),
        Entry(bundleIdentifierPattern: "net.kongshan.jingshan", reason: "净山自身，避免误清理自身数据"),
    ]
}
