import AppKit
import SwiftUI

/// 설정 창. 메뉴바 앱은 창을 열어도 앞으로 나오지 않아 키 입력을 다른 앱이 받을 수 있으므로,
/// 열 때마다 앱을 활성화하고 창을 키 창으로 만든다.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
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
        let window = NSWindow(contentViewController: host)
        window.title = "채우미 설정"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(Self.contentSize)
        window.contentMinSize = NSSize(width: Self.contentSize.width, height: 360)
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
