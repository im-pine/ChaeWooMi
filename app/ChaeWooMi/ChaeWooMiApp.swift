import SwiftUI

@main
struct ChaeWooMiApp: App {
    @State private var settings = AppSettings()

    var body: some Scene {
        MenuBarExtra("채우미", systemImage: "leaf") {
            SettingsLink { Text("설정…") }
                .keyboardShortcut(",")
            Divider()
            Button("채우미 종료") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        Settings {
            SettingsView(settings: settings)
        }
    }
}
