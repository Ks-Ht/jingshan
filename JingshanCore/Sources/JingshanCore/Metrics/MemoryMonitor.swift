import Darwin
import Foundation

enum MemoryMonitor {
    static func sample() -> MemorySnapshot {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPointer, &count)
            }
        }

        let totalBytes = ProcessInfo.processInfo.physicalMemory
        guard result == KERN_SUCCESS else {
            return MemorySnapshot(totalBytes: totalBytes, usedBytes: 0, freeBytes: totalBytes)
        }

        // Matches what Activity Monitor's memory graph actually counts as
        // "used": active + wired + compressed. `inactive`/`speculative`/
        // `purgeable` pages are reclaimable cache the kernel will happily
        // drop under pressure — treating them as "used" (as a naive
        // `total - free_count` does) overstates real usage by several GB on
        // a typical Mac, since `free_count` alone is usually tiny (macOS
        // aggressively fills unused RAM with reclaimable cache).
        // A plain function call, unlike the `vm_kernel_page_size` global,
        // which Swift 6 strict concurrency flags as shared mutable state.
        let pageSize = UInt64(getpagesize())
        let usedPages = UInt64(stats.active_count) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        let usedBytes = usedPages * pageSize
        let freeBytes = totalBytes > usedBytes ? totalBytes - usedBytes : 0

        return MemorySnapshot(totalBytes: totalBytes, usedBytes: min(usedBytes, totalBytes), freeBytes: freeBytes)
    }
}
