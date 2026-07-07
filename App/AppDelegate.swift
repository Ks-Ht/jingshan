import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        SnapshotHarness.runIfRequested() // exits the process if JINGSHAN_SNAPSHOT=1, before showing any window
        #endif
        NSApp.activate(ignoringOtherApps: true)
        MainActor.assumeIsolated {
            if AppSettings.shared.menuBarEnabled {
                MenuBarViewModel.shared.start() // keep the tray icon/panel live
            }
        }
    }

    /// Quit when the last window closes ONLY if the menu-bar tray is off. With
    /// the tray on, the app stays resident in the menu bar (reopen the window
    /// from the tray's "打开净山").
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        MainActor.assumeIsolated { !AppSettings.shared.menuBarEnabled }
    }
}
