import Foundation

/// Maps known cache-folder names (typically a bundle identifier, but some
/// system caches use a plain name like "GeoServices") to a friendly display
/// name and a `CacheGroup`. Data-driven — bundled as JSON — so growing the
/// list of recognized apps never touches matching logic, mirroring
/// `CriticalPathDenylist`/`ProtectedAppAllowlist`.
public struct AppCacheCatalog: Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        /// Matched against the raw cache folder name. Supports a single
        /// `*` wildcard, same semantics as `ProtectedAppAllowlist`.
        public let namePattern: String
        public let displayName: String
        public let group: CacheGroup

        public init(namePattern: String, displayName: String, group: CacheGroup) {
            self.namePattern = namePattern
            self.displayName = displayName
            self.group = group
        }
    }

    public let entries: [Entry]

    public init(entries: [Entry]) {
        self.entries = entries
    }

    public static let `default`: AppCacheCatalog = {
        loadBundled() ?? AppCacheCatalog(entries: fallbackEntries)
    }()

    /// Returns the first matching entry's display name and group, if any
    /// catalog entry recognizes this name.
    public func classify(name: String) -> (displayName: String, group: CacheGroup)? {
        for entry in entries where matches(pattern: entry.namePattern, value: name) {
            return (entry.displayName, entry.group)
        }
        return nil
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

    private static func loadBundled() -> AppCacheCatalog? {
        guard let url = Bundle.module.url(forResource: "AppCacheCatalog", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else {
            return nil
        }
        return AppCacheCatalog(entries: entries)
    }

    /// Used only if the bundled JSON resource fails to load. Kept in sync
    /// by hand as a last-resort fallback; the JSON resource is the source
    /// of truth day-to-day.
    static let fallbackEntries: [Entry] = [
        Entry(namePattern: "com.apple.dt.Xcode", displayName: "Xcode", group: .devTools),
        Entry(namePattern: "com.microsoft.VSCode*", displayName: "Visual Studio Code", group: .devTools),
        Entry(namePattern: "com.tencent.xinWeChat", displayName: "微信", group: .communication),
        Entry(namePattern: "com.tencent.WeWorkMac", displayName: "企业微信", group: .communication),
    ]
}
