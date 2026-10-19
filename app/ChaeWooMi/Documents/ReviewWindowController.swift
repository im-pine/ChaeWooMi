import AppKit
import ChaeWooMiCore
import SwiftUI

/// 검토 모달 창 (디자인 약 1180×724, DOC-017). 이력서 · 자소서가 각자 창을 써 함께 검토한다 (사용자 요청 2026-10-19)
@MainActor
final class ReviewWindowController {
    static let contentSize = NSSize(width: 1180, height: 724)

    let model = ReviewModel()
    let kind: DocumentKind
    private weak var controller: DocumentController?
    private var window: NSWindow?

    init(controller: DocumentController, kind: DocumentKind) {
        self.controller = controller
        self.kind = kind
    }

    func show(draft: URL, layout: VaultLayout?) {
        model.open(draft, layout: layout)
        let window = window ?? makeWindow()
        self.window = window
        window.title = draft.deletingPathExtension().lastPathComponent
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    /// 닫았거나 가려진 모달을 다시 앞으로 (같은 초안 작업이 이어지는 중일 때)
    func reshow() {
        guard let window else { return }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    /// 상태가 바뀌면 세션이 고친 초안을 다시 불러오고, 승인했거나(PDF 생성 · 완료) 보관했으면 닫는다.
    /// 승인 뒤 진행은 카드에서 본다 (사용자 요청 2026-10-18)
    func refresh() {
        model.reloadIfChanged()
        guard let phase = controller?.workflow(kind).phase else { return }
        if DocumentWorkflow.closesReview(phase) { window?.orderOut(nil) }
    }

    private func makeWindow() -> NSWindow {
        guard let controller else { return NSWindow() }
        let host = NSHostingController(rootView: ReviewView(controller: controller, kind: kind, model: model))
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
        // 다른 앱(공고를 보던 Chrome 등)으로 넘어가도 숨기지 않는다 (NSPanel 기본값은 숨김)
        window.hidesOnDeactivate = false
        window.center()
        // 두 모달이 함께 열려도 겹쳐 가려지지 않게 자기소개서 창은 조금 비켜 둔다
        if kind == .coverLetter { window.setFrameOrigin(window.frame.origin.applying(.init(translationX: 40, y: -40))) }
        return window
    }
}
