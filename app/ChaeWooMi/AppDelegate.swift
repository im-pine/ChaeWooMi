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
    private(set) lazy var documents = DocumentController(settings: settings, sessions: sessions, cards: cards)
    private(set) lazy var settingsWindow = SettingsWindowController { [unowned self] in
        SettingsView(settings: settings, bridge: bridge, sessions: sessions)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        cards.start()
        cards.documents = documents
        sessions.onReply = { [unowned self] reply in documents.received(reply) }
        settings.onVaultPathChange = { [unowned self] in
            cards.reloadVault()
            cards.handle(.recheck)
        }
        bridge.onPage = { [unowned self] message in self.route(message) }
        launcher.show()
        bridge.start()
        // 볼트 경로가 없으면(첫 실행) 설정부터 연다
        if settings.vaultPath == nil { settingsWindow.show() }
        #if DEBUG
        SettingsTypingSelfTest.runIfRequested(
            open: { [unowned self] in
                settingsWindow.show()
                return settingsWindow.window
            },
            readName: { [unowned self] in settings.sessionRoster.name(for: .jobAnalysis) }
        )
        #endif
    }

    /// Dock 아이콘 우클릭 메뉴 (APP-018): 지정 외 사이트에서 수동 카드를 띄운다
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: "플로팅 활성화", action: #selector(activateFloating), keyEquivalent: "").target = self
        return menu
    }

    @objc private func activateFloating() {
        cards.handle(.manualActivated)
        launcher.show()
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
        case .hello, .applyComplete: break  // 지원 완료 감지는 3단계 앱 PR에서 카드로 연결
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        bridge.stop()
        sessions.stop()
    }
}
