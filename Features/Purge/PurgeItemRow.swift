import JingshanCore
import SwiftUI

struct PurgeItemRow: View {
    let candidate: PurgeCandidate
    let viewModel: PurgeViewModel

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Toggle(
                isOn: Binding(
                    get: { viewModel.isSelected(candidate) },
                    set: { viewModel.setSelected(candidate, $0) }
                )
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(candidate.projectName)
                            .fontWeight(.medium)
                        Text(candidate.artifactLabel)
                            .foregroundStyle(.secondary)
                        if candidate.isRecent {
                            Text("最近修改")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(RiskTint.caution.opacity(0.15), in: Capsule())
                                .foregroundStyle(RiskTint.caution)
                        }
                    }
                    Text(candidate.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(candidate.riskNote)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.checkbox)

            Spacer()

            if let sizeBytes = candidate.sizeBytes {
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
}
