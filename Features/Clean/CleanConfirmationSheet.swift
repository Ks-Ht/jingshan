import JingshanCore
import SwiftUI

struct CleanConfirmationSheet: View {
    let selectedCount: Int
    let totalBytes: Int64
    let onConfirm: (_ permanently: Bool) -> Void
    let onCancel: () -> Void

    @State private var permanently = false
    @State private var acknowledgedPermanent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("确认清理")
                .font(.title2.bold())

            Text("将处理 \(selectedCount) 项，共 \(ByteFormatter.string(fromBytes: totalBytes))。")

            Toggle("永久删除（不进废纸篓，无法恢复）", isOn: $permanently)

            if permanently {
                Toggle("我知道这无法撤销", isOn: $acknowledgedPermanent)
                    .foregroundStyle(.red)
            } else {
                Text("默认会移动到废纸篓，需要时可以找回。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("取消", role: .cancel) {
                    onCancel()
                }
                Button(permanently ? "永久删除" : "移到废纸篓") {
                    onConfirm(permanently)
                }
                .buttonStyle(.borderedProminent)
                .tint(permanently ? .red : .accentColor)
                .disabled(permanently && !acknowledgedPermanent)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

#Preview {
    CleanConfirmationSheet(selectedCount: 12, totalBytes: 3_400_000_000, onConfirm: { _ in }, onCancel: {})
}
