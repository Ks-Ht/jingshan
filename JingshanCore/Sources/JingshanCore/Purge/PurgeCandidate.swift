import Foundation

/// One build-artifact directory Purge found, ready for the user to review.
public struct PurgeCandidate: Identifiable, Sendable, Equatable {
    public let id: String
    public let path: String
    /// The nearest containing project directory's name (the artifact's
    /// parent directory), e.g. "my-react-app" for
    /// `~/Projects/my-react-app/node_modules`.
    public let projectName: String
    public let artifactLabel: String
    public let sizeBytes: Int64?
    /// True when the *project* directory (not the artifact itself) was
    /// modified within the recency threshold — a signal this project is
    /// still being actively worked on, so its artifacts default to
    /// unselected rather than assumed safe to nuke right now.
    public let isRecent: Bool
    public let riskNote: String

    public init(
        id: String,
        path: String,
        projectName: String,
        artifactLabel: String,
        sizeBytes: Int64?,
        isRecent: Bool,
        riskNote: String
    ) {
        self.id = id
        self.path = path
        self.projectName = projectName
        self.artifactLabel = artifactLabel
        self.sizeBytes = sizeBytes
        self.isRecent = isRecent
        self.riskNote = riskNote
    }
}
