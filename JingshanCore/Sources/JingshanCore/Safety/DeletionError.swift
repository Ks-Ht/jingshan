import Foundation

public enum DeletionError: Error, Equatable, Sendable {
    case validationFailed(PathValidationError)
    case permanentDeleteNotConfirmed
    case filesystemError(description: String)
}
