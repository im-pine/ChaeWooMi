import SwiftUI

@main
struct ChaeWooMiApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra("채우미", systemImage: "leaf") {
            LauncherMenu(settings: appDelegate.settings, launcher: appDelegate.launcher)
            Button("설정…") { appDelegate.settingsWindow.show() }
                .keyboardShortcut(",")
            Divider()
            QuitMenu(settings: appDelegate.settings)
        }
    }
}
