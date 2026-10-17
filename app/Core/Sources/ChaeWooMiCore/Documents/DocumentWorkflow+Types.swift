import Foundation

extension DocumentWorkflow {
    public enum Phase: Equatable, Sendable {
        case idle
        /// JOB-ANALYSIS 분석 요청을 보내고 `## 공고 해석`을 기다림 (ANL-004)
        case analyzing(requestID: String)
        /// 초안 요청을 보내고 초안 `.md`를 기다림
        case drafting(requestID: String)
        /// 검토 모달 (초안 있음, waiting_review)
        case reviewing
        /// 수정 명령 처리 중 → 편집 잠금 (DOC-026)
        case commanding(requestID: String)
        /// 승인 → PDF 생성 요청 후 PDF를 기다림 (DOC-022)
        case generatingPDF(requestID: String)
        /// PDF가 초안보다 최신 (DOC-025)
        case completed
        /// 세션 실패 · 결과 파일 없음. `retry`로 같은 단계를 다시 요청한다 (AGT-008 · ANL-003)
        case failed(Failure)
        /// 초안 보관: 모달만 닫고 PDF는 만들지 않음 (DOC-024)
        case archived
    }

    public struct Failure: Equatable, Sendable {
        public let step: Step
        public let reason: String
        public let missing: [String]
    }

    public enum Step: Equatable, Sendable {
        case analysis, draft, pdf
    }

    /// 수정 명령 하나 (화면에는 사용자 명령과 상태만, DOC-019 · DOC-020)
    public struct Command: Equatable, Sendable {
        public let id: String
        public let text: String
        public internal(set) var status: DocumentCommandStatus
    }

    /// 사용자가 시작할 때 주는 것
    public struct Input: Equatable, Sendable {
        public let kind: DocumentKind
        public let company: String
        public let platform: String
        public let url: String
        public let postingText: String?
        /// 자소서 문항 (이력서는 비어 있음)
        public let questions: [CoverLetterQuestion]

        public init(
            kind: DocumentKind, company: String, platform: String, url: String,
            postingText: String?, questions: [CoverLetterQuestion] = []
        ) {
            self.kind = kind
            self.company = company
            self.platform = platform
            self.url = url
            self.postingText = postingText
            self.questions = questions
        }
    }

    public enum Event: Equatable, Sendable {
        case start(Input, DocumentSnapshot)
        /// 이미 있는 초안(초안 있음 아이콘)을 검토 모달로 다시 연다. 세션 요청 없음
        case reopen(Input, DocumentSnapshot)
        /// 볼트 파일이 바뀜 (FSEvents)
        case files(DocumentSnapshot)
        case reply(SessionReply)
        /// 검토 모달 오른쪽 수정 명령 (사용자가 직접 고쳤는지 함께)
        case command(String, userEdited: Bool)
        case approve(userEdited: Bool)
        case archive
        /// 같은 단계를 다시 요청. 분석 실패면 사용자 보완 글을 붙일 수 있다 (ANL-003)
        case retry(supplement: String?)
        case cancel
    }

    /// 상태 기계가 앱에 시키는 일
    public enum Effect: Equatable, Sendable {
        case send(SessionRequest, id: String)
        case openReview(URL)
        /// 회신 아래 `[CAREER-DB 반영 요청]` → 복사 카드 (DOC-031)
        case showCareerRequest(String)
        /// 끝남 (완료 · 실패 · 보관 · 취소) → 문서 잠금 해제 (AGT-009 · DOC-010)
        case releaseLock
    }
}
