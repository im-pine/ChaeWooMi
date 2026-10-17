import Foundation

/// 채우미 → 역할 세션 요청 (볼트 `00.0.7 채우미 연동 지침` 2 · 3장 형식).
public enum SessionRequest: Equatable, Sendable {
    /// `supplement`: 분석 실패 뒤 사용자가 보완한 글 (ANL-003). 사용자 입력이라 비신뢰 블록에 넣지 않는다
    case analysis(company: String, platform: String, url: String, postingText: String?, supplement: String? = nil)
    case resumeDraft(company: String, url: String, postingText: String?)
    case coverLetterDraft(company: String, url: String, postingText: String?, questions: [CoverLetterQuestion])
    case edit(company: String, kind: DocumentKind, draftPath: String, command: String, userEdited: Bool)
    case pdf(company: String, kind: DocumentKind, draftPath: String, userEdited: Bool)
    case record(company: String, role: String, platform: String, submitted: CalendarDay)

    /// 받는 세션 (AGT-005). 분석 · 지원 기록은 JOB-ANALYSIS, 이력서는 RESUME, 자소서는 APPLICATION
    public var role: SessionRole {
        switch self {
        case .analysis, .record: .jobAnalysis
        case .resumeDraft: .resume
        case .coverLetterDraft: .application
        case let .edit(_, kind, _, _, _), let .pdf(_, kind, _, _): kind == .resume ? .resume : .application
        }
    }

    public var kindLabel: String {
        switch self {
        case .analysis: "공고 분석"
        case .resumeDraft: "이력서 초안"
        case .coverLetterDraft: "자소서 초안"
        case .edit: "수정"
        case .pdf: "PDF 생성"
        case .record: "지원 기록"
        }
    }

    /// 세션에 보낼 글 (글자 그대로 전달된다)
    public func text(id: String) -> String {
        ([RequestText.header(kindLabel, id: id)] + fields + untrusted).joined(separator: "\n")
    }

    private var fields: [String] {
        switch self {
        case let .analysis(company, platform, url, _, supplement):
            ["회사: \(company)", "플랫폼: \(platform)", "공고 주소: \(url)"]
                + (supplement.map { ["사용자 보완: \(RequestText.oneLine($0))"] } ?? [])
        case let .resumeDraft(company, url, _):
            ["회사: \(company)", "공고 주소: \(url)"]
        case let .coverLetterDraft(company, url, _, questions):
            ["회사: \(company)", "공고 주소: \(url)", "문항:"] + questions.enumerated().map { $1.line(number: $0 + 1) }
        case let .edit(company, _, path, command, edited):
            ["회사: \(company)", "초안: \(path)", RequestText.edited(edited), "수정 명령: \(RequestText.oneLine(command))"]
        case let .pdf(company, _, path, edited):
            ["회사: \(company)", "초안: \(path)", RequestText.edited(edited)]
        case let .record(company, role, platform, submitted):
            ["회사: \(company)", "직무: \(role)", "플랫폼: \(platform)", "제출일: \(submitted)"]
        }
    }

    /// 공고 원문은 비신뢰 자료 블록으로 감싼다 (AGT-011). 문서 요청에도 지금 공고 원문을 붙인다 (ANL-013)
    private var untrusted: [String] {
        switch self {
        case let .analysis(_, _, _, text, _), let .resumeDraft(_, _, text), let .coverLetterDraft(_, _, text, _):
            RequestText.untrustedBlock("공고 원문", text)
        case .edit, .pdf, .record:
            []
        }
    }
}

/// 자기소개서 문항 (DOC-005 · DOC-006)
public struct CoverLetterQuestion: Equatable, Sendable {
    public let text: String
    /// 글자수 제한. 없으면 강제로 정하지 않는다
    public let limit: Int?
    public let includesSpaces: Bool

    public init(text: String, limit: Int? = nil, includesSpaces: Bool = true) {
        self.text = text
        self.limit = limit
        self.includesSpaces = includesSpaces
    }

    public enum Problem: Equatable, Sendable {
        case noQuestions
        case emptyQuestion(Int)
        case invalidLimit(Int)
    }

    /// 문항 목록 검사. 문항 번호는 1부터
    public static func problems(_ questions: [CoverLetterQuestion]) -> [Problem] {
        guard !questions.isEmpty else { return [.noQuestions] }
        return questions.enumerated().flatMap { index, question -> [Problem] in
            var problems: [Problem] = []
            if question.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                problems.append(.emptyQuestion(index + 1))
            }
            if let limit = question.limit, limit <= 0 { problems.append(.invalidLimit(index + 1)) }
            return problems
        }
    }

    func line(number: Int) -> String {
        let limitText = limit.map { " (\($0)자, 공백 \(includesSpaces ? "포함" : "제외"))" } ?? " (글자수 제한 없음)"
        return "\(number). \(RequestText.oneLine(text))\(limitText)"
    }
}

enum RequestText {
    static let untrustedEnd = "<<<비신뢰 자료 끝>>>"

    static func header(_ kind: String, id: String) -> String {
        "[채우미 요청] \(kind) id=\(id)"
    }

    static func edited(_ edited: Bool) -> String {
        "사용자 직접 수정: \(edited ? "있음" : "없음")"
    }

    /// 항목 값은 한 줄로 (줄바꿈이 다음 항목처럼 읽히지 않게)
    static func oneLine(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    /// 자료 안에 끝 표시가 있어도 블록이 일찍 닫히지 않게 바꿔 둔다
    static func untrustedBlock(_ title: String, _ text: String?) -> [String] {
        guard let text, !text.isEmpty else { return ["공고 원문: 없음"] }
        let safe = text
            .replacingOccurrences(of: untrustedEnd, with: "<<<(자료 안의 끝 표시)>>>")
            .replacingOccurrences(of: "<<<비신뢰 자료:", with: "<<<(자료 안의 시작 표시):")
        return ["<<<비신뢰 자료: \(title)>>>", safe, untrustedEnd]
    }
}
