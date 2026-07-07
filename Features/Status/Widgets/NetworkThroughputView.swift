import JingshanCore
import SwiftUI

struct NetworkThroughputView: View {
    let network: NetworkSnapshot

    var body: some View {
        MetricCard(title: "网络", systemImage: "network", tint: SidebarItem.status.tint) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.blue)
                    Text(rateString(network.downloadBytesPerSecond))
                }
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.green)
                    Text(rateString(network.uploadBytesPerSecond))
                }
            }
        }
    }

    private func rateString(_ bytesPerSecond: Double) -> String {
        "\(ByteFormatter.string(fromBytes: Int64(bytesPerSecond)))/s"
    }
}

#Preview {
    NetworkThroughputView(network: NetworkSnapshot(downloadBytesPerSecond: 540_000, uploadBytesPerSecond: 21_000))
        .padding()
}
