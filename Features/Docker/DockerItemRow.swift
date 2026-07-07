import JingshanCore
import SwiftUI

struct DockerItemRow: View {
    let item: DockerCleanableItem
    let viewModel: DockerViewModel

    var body: some View {
        CategoryRow(
            title: item.displayName,
            subtitle: item.detail,
            risk: item.risk.categoryRowRisk,
            riskNote: item.riskNote,
            sizeText: item.sizeBytes.map(ByteFormatter.string(fromBytes:)),
            isSelected: viewModel.isSelected(item),
            onToggle: { viewModel.setSelected(item, $0) }
        )
    }
}

extension DockerRiskLevel {
    var categoryRowRisk: CategoryRowRisk? {
        switch self {
        case .safe: return nil
        case .caution: return .caution
        case .destructive: return .destructive
        }
    }
}
