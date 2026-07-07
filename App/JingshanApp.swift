import SwiftUI

@main
struct JingshanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowResizability(.contentMinSize)
        // Nav lives in a custom top bar, so hide the system title bar and let
        // content run to the top edge; `TopNavBar` insets its leading edge to
        // clear the traffic-light controls that now float over it.
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView()
        }
    }
}
