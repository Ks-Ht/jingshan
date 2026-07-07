import JingshanCore
import SwiftUI

struct DockerItemRow: View {
    let item: DockerCleanableItem
    let viewModel: DockerViewModel

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Toggle(
                isOn: Binding(
                    get: { viewModel.isSelected(item) },
                    set: { viewModel.setSelected(item, $0) }
                )
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(item.displayName)
                        riskBadge
                    }
                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.riskNote)
                        .font(.caption2)
                        .foregroundStyle(item.risk == .destructive ? RiskTint.destructive : .secondary)
                }
            }
            .toggleStyle(.checkbox)

            Spacer()

            if let sizeBytes = item.sizeBytes {
                Text(ByteFormatter.string(fromBytes: sizeBytes))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                Text("大小未知")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var riskBadge: some View {
        switch item.risk {
        case .safe:
            EmptyView()
        case .caution:
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(RiskTint.caution)
        case .destructive:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(RiskTint.destructive)
        }
    }
}
