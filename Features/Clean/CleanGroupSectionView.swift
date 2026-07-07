import JingshanCore
import SwiftUI

struct CleanGroupSectionView: View {
    let group: CleanDisplayGroup
    let viewModel: CleanViewModel

    @State private var isExpanded = false

    private var selectableItems: [ScannableItem] {
        group.items.map(\.item).filter { !$0.isProtected }
    }

    private var selectedCount: Int {
        group.items.filter { viewModel.isSelected($0.item) }.count
    }

    private var totalCount: Int { group.items.count }

    private var selectionState: TriState {
        if selectedCount == 0 { return .off }
        if selectedCount == totalCount { return .on }
        return .partial
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                TriStateCheckbox(state: selectionState) {
                    viewModel.setSelected(selectableItems, selectionState != .on)
                }
                .disabled(selectableItems.isEmpty)
                .padding(.top, 2)

                Image(systemName: group.group.systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(group.group.displayName)
                            .font(.headline)
                        Text("已选 \(selectedCount)/\(totalCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(group.group.groupDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(ByteFormatter.string(fromBytes: group.totalBytes))
                    .foregroundStyle(.secondary)

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(group.items) { classified in
                        ClassifiedItemRow(classified: classified, viewModel: viewModel)
                            .padding(.leading, 32)
                    }
                }
            }
        }
    }
}
