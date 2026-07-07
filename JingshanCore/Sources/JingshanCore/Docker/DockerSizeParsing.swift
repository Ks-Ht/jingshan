import Foundation

/// Docker CLI formats sizes as human-readable strings (e.g. "245MB",
/// "1.23GB"), not raw byte counts, using base-1000 (decimal) units — not
/// base-1024. Parsing failures return `nil` rather than guessing, matching
/// this app's convention of an honest "unknown" over a wrong number.
enum DockerSizeParsing {
    static func parseBytes(from text: String) -> Int64? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.caseInsensitiveCompare("N/A") != .orderedSame else { return nil }

        guard let regex = try? NSRegularExpression(pattern: #"^([0-9]*\.?[0-9]+)\s*([a-zA-Z]+)$"#),
            let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
            let numberRange = Range(match.range(at: 1), in: trimmed),
            let unitRange = Range(match.range(at: 2), in: trimmed),
            let value = Double(trimmed[numberRange])
        else {
            return nil
        }

        let multiplier: Double
        switch trimmed[unitRange].lowercased() {
        case "b": multiplier = 1
        case "kb": multiplier = 1_000
        case "mb": multiplier = 1_000_000
        case "gb": multiplier = 1_000_000_000
        case "tb": multiplier = 1_000_000_000_000
        case "pb": multiplier = 1_000_000_000_000_000
        default: return nil
        }

        return Int64(value * multiplier)
    }

    /// Some Docker CLI fields append parenthetical context, e.g.
    /// "1.8GB (56%)" (system df reclaimable) or "0B (virtual 117MB)"
    /// (container size). Parses only the leading size, ignoring the rest.
    static func parseLeadingBytes(from text: String) -> Int64? {
        let leading = text.split(separator: "(", maxSplits: 1).first.map(String.init) ?? text
        return parseBytes(from: leading)
    }
}
