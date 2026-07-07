import SwiftUI

protocol ConfirmSheetItem: Identifiable {
    var displayName: String { get }
    /// Pre-formatted (e.g. via `ByteFormatter`); nil renders "大小未知".
    var sizeText: String? { get }
    var riskBadge: CategoryRowRisk? { get }
}

/// The shared confirm-sheet shell: itemized review list (each item + its
/// size) + total + a review-first "move to Trash vs. permanently delete"
/// gate, closing a real gap the four existing confirmation sheets share
/// today — none of them list items individually, only an aggregate count +
/// total. Module-specific risk logic (Docker's destructive-tier
/// acknowledgment, Uninstaller's residual-tier acknowledgment) is injected
/// via `extraAcknowledgment` rather than hard-coded here, since those
/// genuinely differ per module and forcing one rigid shape would either
/// under-fit Docker (which has no permanent-delete concept at all) or
/// under-fit Uninstaller (which needs two independent gates).
struct ConfirmSheetShell<Item: ConfirmSheetItem, ExtraAcknowledgment: View>: View {
    let title: String
    let items: [Item]
    let totalSizeText: String
    /// Docker passes `false` — it has no permanent-delete concept at all,
    /// only Trash-routed filesystem paths or `docker` CLI removals.
    var permanentDeleteToggle: Bool = true
    var permanentDeleteLabel: String = "永久删除（不进废纸篓，无法恢复）"
    @ViewBuilder var extraAcknowledgment: (_ permanently: Bool) -> ExtraAcknowledgment
    /// Additional gate beyond the built-in permanent-delete acknowledgment —
    /// e.g. Docker's destructive-tier toggle, Uninstaller's residual-tier
    /// toggle. Defaults to always-satisfied for modules with no extra gate.
    var extraAcknowledgmentSatisfied: (_ permanently: Bool) -> Bool = { _ in true }
    let onConfirm: (_ permanently: Bool) -> Void
    let onCancel: () -> Void

    @State private var permanently = false
    @State private var acknowledgedPermanent = false

    private var confirmDisabled: Bool {
        (permanentDeleteToggle && permanently && !acknowledgedPermanent) || !extraAcknowledgmentSatisfied(permanently)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.bold())

            if !items.isEmpty {
                List(items) { item in
                    HStack {
                        HStack(spacing: 4) {
                            Text(item.displayName)
                            if let riskBadge = item.riskBadge {
                                Image(systemName: riskBadge.icon)
                                    .foregroundStyle(riskBadge.tint)
                                    .font(.caption)
                                    .accessibilityLabel(riskBadge.spokenDescription)
                            }
                        }
                        Spacer()
                        Text(item.sizeText ?? "大小未知")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
                .listStyle(.plain)
                .frame(minHeight: 120, maxHeight: 220)
            }

            HStack {
                Text("合计")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(totalSizeText)
                    .font(.headline)
                    .monospacedDigit()
            }

            if permanentDeleteToggle {
                Toggle(permanentDeleteLabel, isOn: $permanently)
                if permanently {
                    Toggle("我知道这无法撤销", isOn: $acknowledgedPermanent)
                        .foregroundStyle(RiskTint.irreversible)
                } else {
                    Text("默认会移动到废纸篓，需要时可以找回。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            extraAcknowledgment(permanently)

            HStack {
                Spacer()
                Button("取消", role: .cancel, action: onCancel)
                Button(permanently ? "永久删除" : "确认清理") {
                    onConfirm(permanently)
                }
                .buttonStyle(.borderedProminent)
                .tint(permanently ? RiskTint.irreversible : .accentColor)
                .disabled(confirmDisabled)
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}
