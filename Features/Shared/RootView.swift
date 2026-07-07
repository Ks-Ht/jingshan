import SwiftUI

struct RootView: View {
    @State private var tab: AppTab = .home

    // The five module view models are owned here, not inside each module view,
    // for two reasons: (1) top-tab switching recreates the visible view each
    // time, so a view-local `@State` view model would lose its scan results on
    // every tab change; (2) the home page reads all five to show aggregate
    // numbers and drives "一键体检" across them.
    @State private var cleanVM = CleanViewModel()
    @State private var dockerVM = DockerViewModel()
    @State private var purgeVM = PurgeViewModel()
    @State private var uninstallVM = UninstallerViewModel()
    @State private var statusVM = StatusViewModel()

    @State private var lastCheckDate: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            TopNavBar(selection: $tab)
            Divider().opacity(0.5)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(InkPalette.paper)
                .id(tab)               // new identity per tab so the opacity transition fires
                .transition(.opacity)
        }
        // Single source of truth for metric sampling: run only while a tab that
        // shows live metrics (home or status) is active. Centralizing here
        // avoids the appear/disappear race two views sharing `statusVM` would hit.
        .onChange(of: tab, initial: true) { _, newTab in
            if newTab == .home || newTab == .status {
                statusVM.start()
            } else {
                statusVM.stop()
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .home:
            HomeView(
                cleanVM: cleanVM,
                dockerVM: dockerVM,
                purgeVM: purgeVM,
                uninstallVM: uninstallVM,
                statusVM: statusVM,
                lastCheckDate: lastCheckDate,
                onOpen: { open($0) },
                onHealthCheck: runHealthCheck
            )
        case .clean:
            CleanView(viewModel: cleanVM)
        case .docker:
            DockerView(viewModel: dockerVM)
        case .purge:
            PurgeView(viewModel: purgeVM)
        case .uninstall:
            UninstallerView(viewModel: uninstallVM)
        case .status:
            StatusView(viewModel: statusVM)
        }
    }

    private func open(_ destination: AppTab) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            tab = destination
        }
    }

    /// Kicks off a scan in every module and stamps the check time, so the home
    /// tiles and health score reflect a fresh sweep. Each view model guards its
    /// own re-entrancy, so calling these while one is mid-scan is safe.
    private func runHealthCheck() {
        cleanVM.startScan()
        dockerVM.refresh()
        purgeVM.startScan()
        uninstallVM.startScan()
        statusVM.start()
        lastCheckDate = Date()
    }
}

#Preview {
    RootView()
}
