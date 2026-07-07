import JingshanCore
import SwiftUI

struct ResidualCandidateRow: View {
    let candidate: ResidualCandidate
    let viewModel: UninstallerViewModel

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Toggle(
                isOn: Binding(
                    get: { viewModel.isResidualSelected(candidate) },
                    set: { viewModel.setResidualSelected(candidate, $0) }
                )
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(candidate.displayLabel)
                            .fontWeight(.medium)
                        if candidate.tier == .destructive {
                            Text("高风险")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(RiskTint.destructive.opacity(0.15), in: Capsule())
                                .foregroundStyle(RiskTint.destructive)
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
            }
        }
        .padding(.vertical, 4)
    }
}
