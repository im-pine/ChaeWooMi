import AppKit
import ChaeWooMiCore
import SwiftUI

/// 플로팅 패널(런처 · 카드)을 화면 오른쪽 아래에 고정한다. 내용 크기가 바뀌거나 화면 구성이 바뀌면 다시 놓는다.
@MainActor
@Observable
final class FloatingController {
    /// 패널을 띄우지 못함 → 메뉴바에서 다시 표시 안내 (APP-001)
    private(set) var failed = false
    /// 메뉴바에서 숨김 (APP-005)
    private(set) var hidden = false

    @ObservationIgnored private let store: CardStore
    @ObservationIgnored private var panel: FloatingPanel?
    @ObservationIgnored private var screenObserver: NSObjectProtocol?
    @ObservationIgnored private var resizeObserver: NSObjectProtocol?

    init(store: CardStore) {
        self.store = store
    }

    /// 패널을 띄우지 못하면 false
    @discardableResult
    func show() -> Bool {
        // 실행 순간 화면이 없어도(클램셸 등) 나중에 모니터가 연결되면 다시 놓도록 먼저 감시한다
        observeScreens()
        hidden = false
        let shown = place()
        failed = !shown
        return shown
    }

    func hide() {
        hidden = true
        panel?.orderOut(nil)
    }

    private func place() -> Bool {
        guard !hidden, let screen = targetScreen else { return false }
        let panel = panel ?? makePanel()
        self.panel = panel
        let size = panel.contentView?.fittingSize ?? PanelPlacement.launcherSize
        panel.setFrame(PanelPlacement.bottomRight(size: size, in: screen.visibleFrame), display: true)
        panel.orderFrontRegardless()
        return panel.isVisible
    }

    /// 마우스가 있는 화면 (다중 모니터, APP-006). 없으면 주 화면
    private var targetScreen: NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func makePanel() -> FloatingPanel {
        let panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: PanelPlacement.launcherSize))
        let host = ResizingHostingView(rootView: FloatingRoot(store: store))
        host.onResize = { [weak self] in _ = self?.place() }
        panel.contentView = host
        // SwiftUI가 내용에 맞춰 창 크기를 직접 바꾸면(왼쪽 위 고정) 오른쪽 아래로 다시 놓는다.
        // 런처 → 카드로 커질 때 화면 밖으로 잘리던 문제 (실측: 44×44 자리에서 220×114로 오른쪽 · 아래로 커짐)
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.place() }
        }
        return panel
    }

    private func observeScreens() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.place() }
        }
    }
}

/// SwiftUI 내용의 크기가 바뀌면 알려 주는 호스팅 뷰 (런처 ↔ 카드 ↔ 상세)
private final class ResizingHostingView<Content: View>: NSHostingView<Content> {
    var onResize: (@MainActor () -> Void)?

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        let handler = onResize
        DispatchQueue.main.async { MainActor.assumeIsolated { handler?() } }
    }
}
