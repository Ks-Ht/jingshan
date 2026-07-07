import Darwin
import Foundation

/// Network throughput is a delta between two byte-counter samples, so this
/// holds the previous sample internally, same as `CPUMonitor`.
struct NetworkMonitor {
    private var previousSample: (received: UInt64, sent: UInt64, timestamp: Date)?

    mutating func sample() -> NetworkSnapshot {
        let now = Date()
        let counters = Self.currentByteCounters()
        defer { previousSample = (counters.received, counters.sent, now) }

        guard let previous = previousSample else { return .empty }
        let elapsed = now.timeIntervalSince(previous.timestamp)
        guard elapsed > 0 else { return .empty }

        let receivedDelta = counters.received >= previous.received ? counters.received - previous.received : 0
        let sentDelta = counters.sent >= previous.sent ? counters.sent - previous.sent : 0

        return NetworkSnapshot(
            downloadBytesPerSecond: Double(receivedDelta) / elapsed,
            uploadBytesPerSecond: Double(sentDelta) / elapsed
        )
    }

    /// Sums byte counters across every up, non-loopback, non-virtual
    /// interface. A stock Mac has several always-up virtual interfaces
    /// alongside the real one (AirDrop's `awdl0`, Continuity Camera's
    /// `anpi*`, any active VPN's `utun*`, `bridge0`, etc.) — on a real
    /// machine with an active VPN, summing everything roughly doubled the
    /// reported throughput, since the tunnel re-carries traffic that also
    /// passes over the physical interface underneath it. Excluding known
    /// virtual prefixes gets this much closer to what the user would call
    /// "my real network activity"; it's still a sum across whichever
    /// physical interfaces (Wi-Fi + wired) happen to be up at once, since
    /// identifying the true default-route interface needs the routing
    /// table, not just interface flags.
    static let excludedInterfacePrefixes = [
        "utun", "awdl", "llw", "bridge", "anpi", "ap1", "p2p", "gif", "stf",
    ]

    static func isPhysicalCandidate(interfaceName: String) -> Bool {
        !excludedInterfacePrefixes.contains { interfaceName.hasPrefix($0) }
    }

    private static func currentByteCounters() -> (received: UInt64, sent: UInt64) {
        var interfaceListPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaceListPointer) == 0, let firstInterface = interfaceListPointer else {
            return (0, 0)
        }
        defer { freeifaddrs(interfaceListPointer) }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        var cursor: UnsafeMutablePointer<ifaddrs>? = firstInterface

        while let current = cursor {
            defer { cursor = current.pointee.ifa_next }

            let flags = Int32(current.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            guard isUp, !isLoopback,
                let socketAddress = current.pointee.ifa_addr,
                socketAddress.pointee.sa_family == UInt8(AF_LINK),
                let rawData = current.pointee.ifa_data,
                isPhysicalCandidate(interfaceName: String(cString: current.pointee.ifa_name))
            else {
                continue
            }

            let networkData = rawData.withMemoryRebound(to: if_data.self, capacity: 1) { $0.pointee }
            received += UInt64(networkData.ifi_ibytes)
            sent += UInt64(networkData.ifi_obytes)
        }

        return (received, sent)
    }
}
