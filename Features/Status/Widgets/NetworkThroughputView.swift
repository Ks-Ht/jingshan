import JingshanCore
import SwiftUI

struct NetworkThroughputView: View {
    let network: NetworkSnapshot
    let downloadHistory: [Double]
    let uploadHistory: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "network")
                    .foregroundStyle(InkPalette.statusAccent)
                    .accessibilityHidden(true)
                Text("网络")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            HStack(alignment: .top, spacing: 20) {
                directionColumn(icon: "arrow.down.circle.fill", label: "下载", tint: .blue, rate: network.downloadBytesPerSecond, history: downloadHistory)
                directionColumn(icon: "arrow.up.circle.fill", label: "上传", tint: .green, rate: network.uploadBytesPerSecond, history: uploadHistory)
            }
        }
        .bentoCard()
        .accessibilityElement(children: .combine)
    }

    private func directionColumn(icon: String, label: String, tint: Color, rate: Double, history: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                // Unlike most decorative icons in this app, this one carries
                // real meaning (which direction this number is) that isn't
                // otherwise in the text, so it gets a label instead of being
                // hidden.
                Image(systemName: icon).foregroundStyle(tint).font(.caption).accessibilityLabel(label)
                Text(rateString(rate))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Sparkline(values: history, tint: tint)
                .frame(height: 24)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rateString(_ bytesPerSecond: Double) -> String {
        "\(ByteFormatter.string(fromBytes: Int64(bytesPerSecond)))/s"
    }
}

#Preview {
    NetworkThroughputView(
        network: NetworkSnapshot(downloadBytesPerSecond: 540_000, uploadBytesPerSecond: 21_000),
        downloadHistory: [100_000, 300_000, 540_000, 200_000],
        uploadHistory: [10_000, 15_000, 21_000, 18_000]
    )
    .padding()
}
