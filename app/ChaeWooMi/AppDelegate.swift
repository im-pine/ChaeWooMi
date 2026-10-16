import AppKit

/// 앱 수명 주기: 실행 시 런처를 띄우고 브라우저 연결을 열며, 종료 시 브라우저 연결 · 중계 세션을 닫는다.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let bridge = BrowserBridge()
    let sessions = SessionHub()
    let launcher = LauncherController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        launcher.show()
        bridge.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        bridge.stop()
        sessions.stop()
    }
}
