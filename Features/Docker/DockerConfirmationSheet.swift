import JingshanCore
import SwiftUI

struct DockerConfirmationSheet: View {
    let selectedCount: Int
    let totalBytes: Int64
    let hasDestructiveSelection: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var acknowledgedDestructive = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("确认清理 Docker 资源")
                .font(.title2.bold())

            Text("将处理 \(selectedCount) 项，共 \(ByteFormatter.string(fromBytes: totalBytes))。")

            if hasDestructiveSelection {
                Label("包含高风险项（正在运行的容器或数据卷），删除后数据无法恢复。", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
                Toggle("我了解这会永久删除数据，且无法撤销", isOn: $acknowledgedDestructive)
            } else {
                Text("以上操作都可以通过重新拉取镜像或重建容器恢复，不涉及不可逆的数据丢失。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("取消", role: .cancel) {
                    onCancel()
                }
                Button("清理") {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .tint(hasDestructiveSelection ? .red : .accentColor)
                .disabled(hasDestructiveSelection && !acknowledgedDestructive)
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}

#Preview {
    DockerConfirmationSheet(selectedCount: 5, totalBytes: 1_200_000_000, hasDestructiveSelection: true, onConfirm: {}, onCancel: {})
}
