import AppKit

/// 앱 수명 주기: 실행 시 브라우저 연결을 열고 종료 시 닫는다.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let bridge = BrowserBridge()

    func applicationDidFinishLaunching(_ notification: Notification) {
        bridge.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        bridge.stop()
    }
}
