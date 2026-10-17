import AppKit
import ChaeWooMiCore

/// 앱 수명 주기: 실행 시 런처를 띄우고 브라우저 연결을 열며, 종료 시 브라우저 연결 · 중계 세션을 닫는다.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    let bridge = BrowserBridge()
    let sessions = SessionHub()
    private(set) lazy var cards = CardStore(settings: settings)
    private(set) lazy var launcher = FloatingController(store: cards)
    private(set) lazy var settingsWindow = SettingsWindowController { [unowned self] in
        SettingsView(settings: settings, bridge: bridge, sessions: sessions)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        cards.start()
        settings.onVaultPathChange = { [unowned self] in
            cards.reloadVault()
            cards.handle(.recheck)
        }
        bridge.onPage = { [unowned self] message in self.route(message) }
        launcher.show()
        bridge.start()
        // 볼트 경로가 없으면(첫 실행) 설정부터 연다
        if settings.vaultPath == nil { settingsWindow.show() }
    }

    /// Dock 아이콘을 클릭하면(이미 실행 중) 설정 창을 연다
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show()
        return false
    }

    /// 확장이 보낸 공고 · 이동 · 지원 버튼 알림을 카드로 넘긴다
    private func route(_ message: ExtensionToApp) {
        switch message {
        case let .jobPage(page): cards.handle(.page(page))
        case .pageLeft: cards.handle(.pageLeft)
        case let .applyButton(covering): cards.applyButton(covering: covering)
        case .hello: break
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        bridge.stop()
        sessions.stop()
    }
}
