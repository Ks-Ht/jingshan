import Foundation

/// One forensic record of something `DeletionEngine` did or refused to do.
/// Written as JSON Lines so the log is both grep-able and machine-parseable.
public struct OperationLogEntry: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let action: String
    public let originalPath: String
    public let resolvedPath: String
    public let sizeBytes: Int64?
    public let outcome: String
    public let detail: String?

    public init(
        timestamp: Date,
        action: String,
        originalPath: String,
        resolvedPath: String,
        sizeBytes: Int64?,
        outcome: String,
        detail: String?
    ) {
        self.timestamp = timestamp
        self.action = action
        self.originalPath = originalPath
        self.resolvedPath = resolvedPath
        self.sizeBytes = sizeBytes
        self.outcome = outcome
        self.detail = detail
    }
}

public protocol OperationLogging: Sendable {
    func log(_ entry: OperationLogEntry)
}

/// Writes every entry to `~/Library/Logs/Jingshan/operations.log`
/// (JSON Lines, size-rotated). Logging is mandatory in v1 — deliberately
/// not user-toggleable like Mole's `MO_NO_OPLOG` — because it is the only
/// forensic trail once something has been moved to Trash or deleted, and
/// Trash-routing alone does not make that trail unnecessary.
public final class OperationLogger: OperationLogging, @unchecked Sendable {
    public static let defaultLogDirectory = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Logs/Jingshan", isDirectory: true)
    public static let defaultLogFileName = "operations.log"

    private let logFileURL: URL
    private let fileManager: FileManager
    private let maxSizeBytes: Int64
    private let queue = DispatchQueue(label: "net.kongshan.jingshan.operation-logger")

    public init(
        logDirectory: URL = OperationLogger.defaultLogDirectory,
        fileName: String = OperationLogger.defaultLogFileName,
        fileManager: FileManager = .default,
        maxSizeBytes: Int64 = 10 * 1024 * 1024
    ) {
        self.logFileURL = logDirectory.appendingPathComponent(fileName)
        self.fileManager = fileManager
        self.maxSizeBytes = maxSizeBytes
    }

    public func log(_ entry: OperationLogEntry) {
        queue.sync {
            do {
                let directory = logFileURL.deletingLastPathComponent()
                if !fileManager.fileExists(atPath: directory.path) {
                    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                }
                try rotateIfNeeded()

                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                var line = try encoder.encode(entry)
                line.append(0x0A)

                if fileManager.fileExists(atPath: logFileURL.path) {
                    let handle = try FileHandle(forWritingTo: logFileURL)
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: line)
                } else {
                    try line.write(to: logFileURL)
                }
            } catch {
                // Logging must never take down the deletion flow it is
                // observing; failures here are swallowed by design.
            }
        }
    }

    private func rotateIfNeeded() throws {
        guard let attributes = try? fileManager.attributesOfItem(atPath: logFileURL.path),
            let size = (attributes[.size] as? NSNumber)?.int64Value,
            size > maxSizeBytes
        else {
            return
        }
        let rotatedURL = logFileURL.deletingPathExtension().appendingPathExtension("1.log")
        try? fileManager.removeItem(at: rotatedURL)
        try fileManager.moveItem(at: logFileURL, to: rotatedURL)
    }
}
