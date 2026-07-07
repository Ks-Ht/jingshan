import Foundation

/// One thing a scanner found that could be cleaned: a cache folder, a log
/// directory, the whole Trash, etc. Read-only in M2 — nothing here implies
/// selection state or deletion; that arrives with the review/confirm UI.
public struct ScannableItem: Identifiable, Equatable, Sendable {
    /// The normalized, absolute path — unique within a category.
    public let id: String
    public let path: String
    public var sizeBytes: Int64?
    /// True when the scanner already knows this item should not be
    /// casually offered (e.g. it belongs to a running app). `DeletionEngine`
    /// enforces this independently at delete time; this flag exists so the
    /// UI can warn before the user even gets that far.
    public var isProtected: Bool
    public var ownerAppBundleID: String?
    public var lastModified: Date?
    /// Human-friendly label for display (e.g. "Safari" instead of
    /// "com.apple.Safari"). Falls back to the last path component when nil.
    public var displayLabel: String?

    public init(
        id: String,
        path: String,
        sizeBytes: Int64?,
        isProtected: Bool = false,
        ownerAppBundleID: String? = nil,
        lastModified: Date? = nil,
        displayLabel: String? = nil
    ) {
        self.id = id
        self.path = path
        self.sizeBytes = sizeBytes
        self.isProtected = isProtected
        self.ownerAppBundleID = ownerAppBundleID
        self.lastModified = lastModified
        self.displayLabel = displayLabel
    }

    public var resolvedDisplayLabel: String {
        displayLabel ?? (path as NSString).lastPathComponent
    }
}

/// One scan category's results, e.g. "user caches" or "browser caches".
public struct ScanCategory: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public var items: [ScannableItem]

    public init(id: String, displayName: String, items: [ScannableItem]) {
        self.id = id
        self.displayName = displayName
        self.items = items
    }

    public var totalSizeBytes: Int64 {
        items.reduce(0) { $0 + ($1.sizeBytes ?? 0) }
    }
}

/// Emitted as each category finishes scanning, so the UI can show
/// incremental progress instead of a single blocking spinner.
public struct ScanProgress: Sendable {
    public let categoryID: String
    public let itemCount: Int
    public let totalBytesFoundSoFar: Int64

    public init(categoryID: String, itemCount: Int, totalBytesFoundSoFar: Int64) {
        self.categoryID = categoryID
        self.itemCount = itemCount
        self.totalBytesFoundSoFar = totalBytesFoundSoFar
    }
}
