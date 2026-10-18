import AppKit
import SwiftUI

/// 설정 창. 메뉴바 앱은 창을 열어도 앞으로 나오지 않아 키 입력을 다른 앱이 받을 수 있으므로,
/// 열 때마다 활성화를 요청하고, 거절돼도 키 입력을 받도록 비활성 패널로 만든다.
@MainActor
final class SettingsWindowController {
    private(set) var window: NSWindow?
    private let makeContent: @MainActor () -> SettingsView

    init(makeContent: @escaping @MainActor () -> SettingsView) {
        self.makeContent = makeContent
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    /// 설정 Form은 스크롤 영역이라 스스로 높이를 정하지 않으므로 창 크기를 정해 둔다
    private static let contentSize = NSSize(width: 460, height: 640)

    private func makeWindow() -> NSWindow {
        let host = NSHostingController(rootView: makeContent())
        host.sizingOptions = []
        // 다른 앱이 앞에 있으면 macOS 14의 협조형 활성화가 거절될 수 있다. 비활성 패널은 앱이 앞으로 오지 않아도 키 창이 된다.
        // `.nonactivatingPanel`은 만들 때 줘야 창 서버에 반영된다
        let window = SettingsPanel(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = host
        window.title = "채우미 설정"
        window.setContentSize(Self.contentSize)
        window.contentMinSize = NSSize(width: Self.contentSize.width, height: 360)
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}

/// 앱 활성화와 상관없이 키 창이 되는 설정 창
private final class SettingsPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
