import JingshanCore
import SwiftUI

struct ClassifiedItemRow: View {
    let classified: ClassifiedItem
    let viewModel: CleanViewModel

    var body: some View {
        CategoryRow(
            title: classified.displayName,
            subtitle: classified.item.path,
            risk: classified.item.isProtected ? .caution : nil,
            sizeText: classified.item.sizeBytes.map(ByteFormatter.string(fromBytes:)),
            isSelected: viewModel.isSelected(classified.item),
            isDisabled: classified.item.isProtected,
            disabledReason: classified.item.isProtected ? "应用正在运行或受保护，清理时会自动跳过" : nil,
            onToggle: { viewModel.setSelected(classified.item, $0) }
        )
    }
}
