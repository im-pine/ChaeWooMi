import SwiftUI

@main
struct ChaeWooMiApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra("채우미", systemImage: "leaf") {
            LauncherMenu(launcher: appDelegate.launcher)
            Button("설정…") { appDelegate.settingsWindow.show() }
                .keyboardShortcut(",")
            Divider()
            Button("채우미 종료") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
