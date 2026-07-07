import Foundation

/// One scannable category of cleanup candidates. Each scanner owns exactly
/// one category and knows nothing about the others — `ScanCoordinator` is
/// the only thing that combines them.
public protocol CategoryScanning: Sendable {
    var categoryID: String { get }
    var displayName: String { get }
    func scan() async -> ScanCategory
}
