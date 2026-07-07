import SwiftUI

struct RootView: View {
    @State private var selection: SidebarItem? = .clean

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            switch selection {
            case .clean:
                CleanView()
            case .docker:
                DockerView()
            case .purge:
                PurgeView()
            case .uninstaller:
                UninstallerView()
            case .status:
                StatusView()
            case .none:
                CleanView()
            }
        }
        .navigationTitle("净山")
    }
}

#Preview {
    RootView()
}
