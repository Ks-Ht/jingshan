import AppKit
import JingshanCore
import SwiftUI

struct UninstallerAppRow: View {
    let app: InstalledApplication

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                .resizable()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(app.displayName)
                    .font(.callout)
                    .lineLimit(1)
                if let version = app.versionString {
                    Text("版本 \(version)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            if let sizeBytes = app.sizeBytes {
                Text(ByteFormatter.string(fromBytes: sizeBytes))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
