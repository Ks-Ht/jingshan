import JingshanCore
import SwiftUI

struct ResidualCandidateRow: View {
    let candidate: ResidualCandidate
    let viewModel: UninstallerViewModel

    var body: some View {
        CategoryRow(
            title: candidate.displayLabel,
            subtitle: candidate.path,
            risk: candidate.tier.categoryRowRisk,
            riskNote: candidate.riskNote,
            sizeText: candidate.sizeBytes.map(ByteFormatter.string(fromBytes:)),
            isSelected: viewModel.isResidualSelected(candidate),
            onToggle: { viewModel.setResidualSelected(candidate, $0) }
        )
    }
}

extension ResidualRiskTier {
    var categoryRowRisk: CategoryRowRisk? {
        switch self {
        case .safe: return nil
        case .caution: return .caution
        case .destructive: return .destructive
        }
    }
}
