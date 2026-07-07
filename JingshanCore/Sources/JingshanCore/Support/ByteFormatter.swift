import Foundation

public enum ByteFormatter {
    public static func string(fromBytes bytes: Int64) -> String {
        // `ByteCountFormatter` renders 0 as "Zero KB", which reads oddly;
        // show a clean "0 B" instead. (`<= 0` also guards defensively against
        // any negative that slips through.)
        if bytes <= 0 { return "0 B" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
