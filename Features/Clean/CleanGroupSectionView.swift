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
        if selectedCount == selectableItems.count { return .on }
        return .partial
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                TriStateCheckbox(state: selectionState, tint: InkPalette.cleanAccent) {
                    viewModel.setSelected(selectableItems, selectionState != .on)
                }
                // Strong mode deliberately offers no group "select all" — every
                // item must be ticked by hand — so this is disabled while it's on.
                .disabled(selectableItems.isEmpty || viewModel.strongMode)
                .help(viewModel.strongMode ? "强力模式下需逐项勾选，不提供整组全选" : "")
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

                // Real button (keyboard-reachable, hover feedback), not a bare
                // tap gesture — expanding a group is a first-class action.
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "收起分组" : "展开分组")
            }
            .padding(.vertical, 8)
            .hoverHighlight()

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
