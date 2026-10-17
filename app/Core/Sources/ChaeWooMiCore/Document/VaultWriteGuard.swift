import Foundation

/// 채우미가 직접 쓰는 볼트 파일은 모달에서 편집 중인 초안 Markdown뿐이다 (SEC-005).
/// 12.0 · 공고 · Career DB 등 나머지 파일은 세션 요청으로만 바뀐다.
public enum VaultWriteGuard {
    public enum Refusal: Error, Equatable {
        /// 지금 모달에서 편집 중인 초안이 아님
        case notEditingDraft
        /// 산출물 폴더(11.0.0 Output) 밖
        case outsideOutputFolder
        /// Markdown이 아님 (PDF 등은 세션이 만든다)
        case notMarkdown
        /// 볼트에 산출물 폴더가 없음
        case noOutputFolder
    }

    /// `target`에 써도 되는지 판단한다. 심볼릭 링크 · `..`를 풀어 실제 위치로 비교한다.
    public static func check(target: URL, editingDraft: URL?, layout: VaultLayout) throws(Refusal) {
        guard let output = layout.outputFolder else { throw .noOutputFolder }
        let resolved = target.resolvingSymlinksInPath().standardizedFileURL
        guard resolved.pathExtension.lowercased() == "md" else { throw .notMarkdown }
        let outputPath = output.resolvingSymlinksInPath().standardizedFileURL.path + "/"
        guard resolved.path.hasPrefix(outputPath) else { throw .outsideOutputFolder }
        guard let editingDraft,
              editingDraft.resolvingSymlinksInPath().standardizedFileURL == resolved else {
            throw .notEditingDraft
        }
    }
}

/// 편집 중인 초안 Markdown 저장. 쓰기 전에 항상 `VaultWriteGuard`를 거친다.
public struct DraftWriter: Sendable {
    public let layout: VaultLayout
    public let editingDraft: URL

    public init(layout: VaultLayout, editingDraft: URL) {
        self.layout = layout
        self.editingDraft = editingDraft
    }

    public enum WriteError: Error, Equatable {
        case refused(VaultWriteGuard.Refusal)
        case failed(String)
    }

    public func save(_ markdown: String, to target: URL) throws(WriteError) {
        do {
            try VaultWriteGuard.check(target: target, editingDraft: editingDraft, layout: layout)
        } catch {
            throw .refused(error)
        }
        do {
            try markdown.write(to: target, atomically: true, encoding: .utf8)
        } catch {
            throw .failed(error.localizedDescription)
        }
    }
}
