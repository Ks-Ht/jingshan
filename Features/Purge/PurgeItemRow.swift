import JingshanCore
import SwiftUI

struct PurgeItemRow: View {
    let candidate: PurgeCandidate
    let viewModel: PurgeViewModel

    var body: some View {
        CategoryRow(
            title: "\(candidate.projectName) · \(candidate.artifactLabel)",
            subtitle: candidate.path,
            risk: candidate.isRecent ? .caution : nil,
            riskNote: candidate.isRecent ? "最近修改 · \(candidate.riskNote)" : candidate.riskNote,
            sizeText: candidate.sizeBytes.map(ByteFormatter.string(fromBytes:)),
            isSelected: viewModel.isSelected(candidate),
            disabledReason: candidate.isRecent ? "7 天内修改过，默认不勾选" : nil,
            tint: InkPalette.purgeAccent,
            onToggle: { viewModel.setSelected(candidate, $0) }
        )
    }
}
