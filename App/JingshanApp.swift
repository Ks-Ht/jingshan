import SwiftUI

@main
struct JingshanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var settings = AppSettings.shared
    @State private var menuBar = MenuBarViewModel.shared

    var body: some Scene {
        WindowGroup(id: "main") {
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

        // Menu-bar tray (A4): a throttled live monitor + quick actions. When
        // enabled the app stays resident after the window closes (see
        // AppDelegate) so the tray keeps working.
        MenuBarExtra(isInserted: $settings.menuBarEnabled) {
            MenuBarContentView(model: menuBar)
        } label: {
            MenuBarLabel(model: menuBar, showsPercent: settings.menuBarShowsPercent)
        }
        .menuBarExtraStyle(.window)
    }
}
