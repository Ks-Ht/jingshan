import JingshanCore
import SwiftUI

struct ClassifiedItemRow: View {
    let classified: ClassifiedItem
    let viewModel: CleanViewModel

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Toggle(
                isOn: Binding(
                    get: { viewModel.isSelected(classified.item) },
                    set: { viewModel.setSelected(classified.item, $0) }
                )
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(classified.displayName)
                        if classified.item.isProtected {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(RiskTint.caution)
                                .help("应用正在运行或受保护，清理时会自动跳过")
                        }
                    }
                    Text(classified.item.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .toggleStyle(.checkbox)
            .disabled(classified.item.isProtected)

            Spacer()

            if let sizeBytes = classified.item.sizeBytes {
                Text(ByteFormatter.string(fromBytes: sizeBytes))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                Text("大小未知")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
