import Foundation

/// 문서 작업 판정에 쓰는 볼트 파일 상태 (DB 없음). 분석 완료 · 초안 · PDF를 파일로만 본다.
public struct DocumentSnapshot: Equatable, Sendable {
    /// 회사 폴더 `공고.md`에 `## 공고 해석`이 있음 (ANL-009)
    public let analysisDone: Bool
    /// 가장 최근 연도 산출물 폴더의 초안 `.md`
    public let draft: URL?
    public let draftModified: Date?
    public let pdf: URL?
    public let pdfModified: Date?

    public init(analysisDone: Bool, draft: URL?, draftModified: Date?, pdf: URL?, pdfModified: Date?) {
        self.analysisDone = analysisDone
        self.draft = draft
        self.draftModified = draftModified
        self.pdf = pdf
        self.pdfModified = pdfModified
    }

    /// PDF가 초안보다 최신 (DOC-013 · DOC-025)
    public var pdfIsCurrent: Bool {
        guard let pdfModified else { return false }
        return draftModified.map { pdfModified >= $0 } ?? true
    }

    public static func read(_ kind: DocumentKind, company: String, layout: VaultLayout) -> DocumentSnapshot {
        let folders = CompanyFolders.find(company: company, in: layout)
        let analysis = TaskStateRule.fileState(.analysis, folders: folders) == .completed
        let marker = kind == .resume ? "_이력서_" : "_자기소개서_"
        let files = folders.currentOutputFolders.flatMap(contents).filter { $0.lastPathComponent.contains(marker) }
        let draft = newest(files.filter { $0.pathExtension.lowercased() == "md" })
        let pdf = newest(files.filter { $0.pathExtension.lowercased() == "pdf" })
        return DocumentSnapshot(
            analysisDone: analysis, draft: draft?.url, draftModified: draft?.date, pdf: pdf?.url, pdfModified: pdf?.date
        )
    }

    private static func contents(_ folder: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
    }

    private static func newest(_ files: [URL]) -> (url: URL, date: Date)? {
        files
            .compactMap { url in
                let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                return date.map { (url, $0) }
            }
            .max { $0.1 < $1.1 }
            .map { (url: $0.0, date: $0.1) }
    }
}
