import ChaeWooMiCore
import SwiftUI

@main
struct ChaeWooMiApp: App {
    var body: some Scene {
        MenuBarExtra("채우미", systemImage: "leaf") {
            Button("채우미 종료") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
