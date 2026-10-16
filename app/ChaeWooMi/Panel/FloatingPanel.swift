import AppKit

/// 브라우저 위에 떠 있지만 브라우저 포커스를 뺏지 않는 패널 (non-activating, floating).
final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        // 모든 데스크톱 · 전체 화면 앱 위에도 보인다
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        isMovable = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
    }

    // 클릭은 받되 키 입력 창이 되지 않아 브라우저 입력이 끊기지 않는다
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
