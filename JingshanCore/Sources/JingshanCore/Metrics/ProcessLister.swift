import Foundation

/// A single row in the Top-Processes table.
public struct ProcessUsageRow: Identifiable, Sendable, Equatable {
    public let id: Int32
    public let pid: Int32
    public let name: String
    public let cpuPercent: Double
    public let memoryPercent: Double

    public init(id: Int32, pid: Int32, name: String, cpuPercent: Double, memoryPercent: Double) {
        self.id = id
        self.pid = pid
        self.name = name
        self.cpuPercent = cpuPercent
        self.memoryPercent = memoryPercent
    }
}

/// Lists the busiest processes by shelling out to `/bin/ps` — a stable,
/// documented tool, avoiding the fragile private `libproc`/task-port dance.
/// Read-only; never touches process state.
public enum ProcessLister {
    public enum SortKey: Sendable {
        case cpu
        case memory
    }

    public static func topProcesses(sortedBy key: SortKey = .cpu, limit: Int = 6) async -> [ProcessUsageRow] {
        // -A all, -c command name only (no full path/args), -o custom columns,
        // -r sort by CPU desc, -m sort by memory desc.
        let sortFlag = key == .cpu ? "-r" : "-m"
        guard let output = await run(["-Aceo", "pid=,pcpu=,pmem=,comm=", sortFlag]) else { return [] }

        var rows: [ProcessUsageRow] = []
        for line in output.split(separator: "\n") {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            guard fields.count >= 4,
                  let pid = Int32(fields[0]),
                  let cpu = Double(fields[1]),
                  let mem = Double(fields[2])
            else { continue }
            let name = fields[3...].joined(separator: " ")
            rows.append(ProcessUsageRow(id: pid, pid: pid, name: name, cpuPercent: cpu, memoryPercent: mem))
            if rows.count >= limit { break }
        }
        return rows
    }

    private static func run(_ arguments: [String]) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/ps")
                process.arguments = arguments
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice
                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
