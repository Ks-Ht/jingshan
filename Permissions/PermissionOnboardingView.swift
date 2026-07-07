import SwiftUI

struct PermissionOnboardingView: View {
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("需要完全磁盘访问权限")
                .font(.title2.bold())
            Text("净山需要「完全磁盘访问权限」才能扫描其他应用的缓存、日志等文件。请在系统设置中开启，然后回到净山。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)
            Button("打开系统设置") {
                onOpenSettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    PermissionOnboardingView(onOpenSettings: {})
}
