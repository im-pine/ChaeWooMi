import ChaeWooMiCore
import Foundation
import Observation

/// 검토 모달의 초안 글. 편집하면 초안 파일에 바로 저장하고(DOC-018, 앱이 쓰는 유일한 볼트 파일),
/// 세션이 파일을 고치면 다시 불러온다(DOC-021).
@MainActor
@Observable
final class ReviewModel {
    private(set) var draft: URL?
    var text = "" {
        didSet { if text != lastSaved { save() } }
    }
    /// 마지막 명령 · 승인 이후 사용자가 직접 고쳤는가 (요청에 함께 보낸다, DOC-019 · DOC-022)
    private(set) var userEdited = false
    private(set) var saveError: String?

    @ObservationIgnored private var lastSaved = ""
    @ObservationIgnored private var writer: DraftWriter?

    func open(_ url: URL, layout: VaultLayout?) {
        draft = url
        writer = layout.map { DraftWriter(layout: $0, editingDraft: url) }
        userEdited = false
        load()
    }

    /// 파일이 바깥(세션)에서 바뀌었으면 다시 불러온다. 사용자 편집은 이미 파일에 저장돼 있어 덮어쓰지 않는다
    func reloadIfChanged() {
        guard let draft, let current = try? String(contentsOf: draft, encoding: .utf8), current != lastSaved else {
            return
        }
        lastSaved = current
        text = current
    }

    /// 명령 · 승인을 보낸 뒤에는 다시 "직접 수정 없음"부터 센다
    func markSent() {
        userEdited = false
    }

    private func load() {
        guard let draft else { return }
        let current = (try? String(contentsOf: draft, encoding: .utf8)) ?? ""
        lastSaved = current
        text = current
    }

    private func save() {
        guard let draft, let writer else { return }
        do {
            try writer.save(text, to: draft)
            lastSaved = text
            userEdited = true
            saveError = nil
        } catch {
            saveError = "초안을 저장하지 못했습니다: \(error)"
        }
    }
}
