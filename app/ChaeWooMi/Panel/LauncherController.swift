import AppKit
import ChaeWooMiCore
import SwiftUI

/// 런처 패널을 만들고 화면 오른쪽 아래에 둔다. 화면 구성이 바뀌면 다시 놓는다.
@MainActor
@Observable
final class LauncherController {
    /// 패널을 띄우지 못함 → 메뉴바에서 다시 표시 안내 (APP-001)
    private(set) var failed = false

    @ObservationIgnored private var panel: FloatingPanel?
    @ObservationIgnored private var screenObserver: NSObjectProtocol?

    /// 패널을 띄우지 못하면 false
    @discardableResult
    func show() -> Bool {
        let shown = place()
        failed = !shown
        return shown
    }

    private func place() -> Bool {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return false }
        let panel = panel ?? makePanel()
        let frame = PanelPlacement.bottomRight(size: PanelPlacement.launcherSize, in: screen.visibleFrame)
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        self.panel = panel
        observeScreens()
        return panel.isVisible
    }

    private func makePanel() -> FloatingPanel {
        let panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: PanelPlacement.launcherSize))
        panel.contentView = NSHostingView(rootView: LauncherView())
        return panel
    }

    private func observeScreens() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.show() }
        }
    }
}
