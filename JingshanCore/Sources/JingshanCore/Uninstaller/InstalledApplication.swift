import Foundation

/// A `.app` bundle discovered under one of the scanned Application
/// directories, with just enough metadata to list it and to compute where
/// its leftover files would live.
public struct InstalledApplication: Identifiable, Sendable, Equatable {
    public var id: String { path }
    public let path: String
    public let bundleIdentifier: String
    public let displayName: String
    public let versionString: String?
    public var sizeBytes: Int64?

    public init(
        path: String,
        bundleIdentifier: String,
        displayName: String,
        versionString: String?,
        sizeBytes: Int64? = nil
    ) {
        self.path = path
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.versionString = versionString
        self.sizeBytes = sizeBytes
    }
}
