import Foundation

/// A residual location that actually exists on disk for a specific app,
/// ready to display and (optionally) delete.
public struct ResidualCandidate: Identifiable, Sendable, Equatable {
    public var id: String { path }
    public let path: String
    public let displayLabel: String
    public let tier: ResidualRiskTier
    public let riskNote: String
    public var sizeBytes: Int64?

    public init(
        path: String,
        displayLabel: String,
        tier: ResidualRiskTier,
        riskNote: String,
        sizeBytes: Int64? = nil
    ) {
        self.path = path
        self.displayLabel = displayLabel
        self.tier = tier
        self.riskNote = riskNote
        self.sizeBytes = sizeBytes
    }
}
