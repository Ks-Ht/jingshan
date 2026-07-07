import JingshanCore
import SwiftUI

struct UninstallerConfirmationSheet: View {
    let appName: String
    let selectedCount: Int
    let totalBytes: Int64
    let hasDestructiveSelection: Bool
    let onConfirm: (_ permanently: Bool) -> Void
    let onCancel: () -> Void

    @State private var permanently = false
    @State private var acknowledgedPermanent = false
    @State private var acknowledgedDestructive = false

    private var confirmDisabled: Bool {
        (permanently && !acknowledgedPermanent) || (hasDestructiveSelection && !acknowledgedDestructive)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("确认卸载「\(appName)」")
                .font(.title2.bold())

            Text("将处理 \(selectedCount) 项，共 \(ByteFormatter.string(fromBytes: totalBytes))。")

            if hasDestructiveSelection {
                Label("包含沙盒容器数据（可能是应用的实际数据而非仅缓存），请确认后再继续。", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
                Toggle("我确认这些容器数据不再需要", isOn: $acknowledgedDestructive)
            }

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
                Button(permanently ? "永久删除" : "卸载") {
                    onConfirm(permanently)
                }
                .buttonStyle(.borderedProminent)
                .tint(permanently ? .red : .accentColor)
                .disabled(confirmDisabled)
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}

#Preview {
    UninstallerConfirmationSheet(
        appName: "示例应用",
        selectedCount: 4,
        totalBytes: 500_000_000,
        hasDestructiveSelection: true,
        onConfirm: { _ in },
        onCancel: {}
    )
}
