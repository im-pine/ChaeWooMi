import AppKit
import ChaeWooMiCore
import SwiftUI

/// 검토 모달 창 (디자인 약 1180×724, DOC-017). 이력서 · 자소서가 같은 창을 쓰되 열 때마다 그 초안만 보인다 (DOC-028)
@MainActor
final class ReviewWindowController {
    static let contentSize = NSSize(width: 1180, height: 724)

    let model = ReviewModel()
    private weak var controller: DocumentController?
    private var window: NSWindow?

    init(controller: DocumentController) {
        self.controller = controller
    }

    func show(draft: URL, layout: VaultLayout?) {
        model.open(draft, layout: layout)
        let window = window ?? makeWindow()
        self.window = window
        window.title = draft.deletingPathExtension().lastPathComponent
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    /// 상태가 바뀌면 세션이 고친 초안을 다시 불러오고, 승인했거나(PDF 생성 · 완료) 보관했으면 닫는다.
    /// 승인 뒤 진행은 카드에서 본다 (사용자 요청 2026-10-18)
    func refresh() {
        model.reloadIfChanged()
        guard let phase = controller?.workflow.phase else { return }
        if DocumentWorkflow.closesReview(phase) { window?.orderOut(nil) }
    }

    private func makeWindow() -> NSWindow {
        guard let controller else { return NSWindow() }
        let host = NSHostingController(rootView: ReviewView(controller: controller, model: model))
        host.sizingOptions = []
        // 다른 앱이 앞에 있어도 키 입력을 받도록 설정 창과 같은 비활성 패널
        let window = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = host
        window.setContentSize(Self.contentSize)
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
