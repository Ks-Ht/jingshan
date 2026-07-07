import JingshanCore
import SwiftUI

/// The local, private cleanup log (A1) with one-click restore-from-Trash (B2).
/// Presented as a sheet from the home page. Restore is non-destructive — it
/// only moves items back out of the Trash to where they came from.
struct CleanupHistoryView: View {
    let onClose: () -> Void

    @State private var store = CleanupHistoryStore.shared
    @State private var restoreResult: RestoreResult?

    private struct RestoreResult: Identifiable {
        let id = UUID()
        let restored: Int
        let failed: Int
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if store.records.isEmpty {
                EmptyStateView(
                    systemImage: "clock.arrow.circlepath",
                    title: "还没有清理记录",
                    message: "清理、构建产物、卸载应用完成后，会在这里留下可追溯的记录，并可一键从废纸篓恢复。"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(store.records) { record in
                    row(record)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 560, height: 560)
        .background(InkPalette.paper)
        .tint(InkPalette.accent)
        .alert(item: $restoreResult) { result in
            Alert(
                title: Text(result.failed == 0 ? "恢复完成" : "部分恢复"),
                message: Text(restoreMessage(result)),
                dismissButton: .default(Text("好"))
            )
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("清理历史").font(.title3.bold())
                Text("累计已释放 ")
                    .font(.caption).foregroundStyle(.secondary)
                + Text(ByteFormatter.string(fromBytes: store.totalFreedBytes))
                    .font(.caption.weight(.semibold)).foregroundColor(InkPalette.accent)
                + Text(" · 共 \(store.totalCleanupCount) 次清理 · 仅保存在本机")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !store.records.isEmpty {
                Button("清空记录") { store.clear() }
                    .tint(.secondary)
            }
            Button("完成") { onClose() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding()
    }

    private func row(_ record: CleanupRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: moduleIcon(record.module))
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(record.module) · 释放 \(ByteFormatter.string(fromBytes: record.freedBytes))")
                    .font(.subheadline.weight(.medium))
                Text(subtitle(record))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if record.restored {
                Label("已恢复", systemImage: "arrow.uturn.backward.circle.fill")
                    .font(.caption)
                    .foregroundStyle(InkPalette.accent)
            } else if record.trashedItems.isEmpty {
                Text("不可恢复")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Button("一键恢复") {
                    let outcome = store.restore(record)
                    restoreResult = RestoreResult(restored: outcome.restored, failed: outcome.failed)
                }
                .buttonStyle(.bordered)
                .help("把这次清理移入废纸篓的文件放回原处")
            }
        }
        .padding(.vertical, 4)
    }

    private func subtitle(_ record: CleanupRecord) -> String {
        var parts = [Self.dateFormatter.string(from: record.date), "\(record.itemCount) 项"]
        if !record.trashedItems.isEmpty && !record.restored {
            parts.append("\(record.trashedItems.count) 项可恢复")
        }
        return parts.joined(separator: " · ")
    }

    private func restoreMessage(_ result: RestoreResult) -> String {
        if result.failed == 0 {
            return "已从废纸篓恢复 \(result.restored) 项到原位置。"
        }
        return "恢复 \(result.restored) 项；\(result.failed) 项未能恢复（可能原位置已被占用，或已不在废纸篓中）。"
    }

    private func moduleIcon(_ module: String) -> String {
        switch module {
        case "清理": return "sparkles"
        case "构建产物": return "hammer"
        case "卸载应用": return "trash"
        default: return "clock"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hans")
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()
}
