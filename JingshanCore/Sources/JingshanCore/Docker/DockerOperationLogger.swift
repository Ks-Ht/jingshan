import Foundation

/// One forensic record of a Docker resource removal attempt. Kept in a
/// separate log file from `OperationLogger`'s file-deletion trail — Docker
/// removals are a different kind of operation (subprocess invocation, not
/// filesystem mutation) and deserve their own audit stream rather than
/// being force-fit into `OperationLogEntry`'s path-shaped fields.
public struct DockerOperationLogEntry: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let kind: String
    public let resourceID: String
    public let displayName: String
    public let arguments: [String]
    public let outcome: String
    public let detail: String?

    public init(timestamp: Date, kind: String, resourceID: String, displayName: String, arguments: [String], outcome: String, detail: String?) {
        self.timestamp = timestamp
        self.kind = kind
        self.resourceID = resourceID
        self.displayName = displayName
        self.arguments = arguments
        self.outcome = outcome
        self.detail = detail
    }
}

public protocol DockerOperationLogging: Sendable {
    func log(_ entry: DockerOperationLogEntry)
}

/// Writes every entry to `~/Library/Logs/Jingshan/docker-operations.log`
/// (JSON Lines, size-rotated) — same shape and mandatory-logging policy as
/// `OperationLogger`.
public final class DockerOperationLogger: DockerOperationLogging, @unchecked Sendable {
    public static let defaultLogDirectory = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Logs/Jingshan", isDirectory: true)
    public static let defaultLogFileName = "docker-operations.log"

    private let logFileURL: URL
    private let fileManager: FileManager
    private let maxSizeBytes: Int64
    private let queue = DispatchQueue(label: "net.kongshan.jingshan.docker-operation-logger")

    public init(
        logDirectory: URL = DockerOperationLogger.defaultLogDirectory,
        fileName: String = DockerOperationLogger.defaultLogFileName,
        fileManager: FileManager = .default,
        maxSizeBytes: Int64 = 10 * 1024 * 1024
    ) {
        self.logFileURL = logDirectory.appendingPathComponent(fileName)
        self.fileManager = fileManager
        self.maxSizeBytes = maxSizeBytes
    }

    public func log(_ entry: DockerOperationLogEntry) {
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
                // Logging must never take down the cleanup flow it is
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
