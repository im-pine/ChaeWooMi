import Foundation

/// 문서 한 건의 진행 (AGT-006): 문서 요청 → (분석이 없으면) 분석 요청 → 초안 → 검토 · 수정 → 승인 → PDF → 완료.
/// 완료 판정은 세션 회신이 아니라 볼트 파일로 한다 (AGT-007). 세션 답변 문장은 다루지 않는다.
public struct DocumentWorkflow: Equatable, Sendable {
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

    public private(set) var phase: Phase = .idle
    public private(set) var input: Input?
    public private(set) var commands: [Command] = []
    public private(set) var careerRequests: [String] = []
    public private(set) var snapshot: DocumentSnapshot?
    /// 요청을 보낸 때의 초안 · PDF 시각 (그보다 새 파일이 생겨야 결과로 본다)
    private var baseline: Date?
    private var nextID: Int
    private let idPrefix: String

    public init(idPrefix: String = UUID().uuidString.prefix(8).lowercased()) {
        self.idPrefix = idPrefix
        nextID = 1
    }

    /// 명령 처리 중에는 편집기를 잠근다 (DOC-026)
    public var editingLocked: Bool {
        if case .commanding = phase { return true }
        return false
    }

    public mutating func handle(_ event: Event) -> [Effect] {
        switch event {
        case let .start(input, snapshot): return start(input, snapshot)
        case let .files(snapshot): return filesChanged(snapshot)
        case let .reply(reply): return replied(reply)
        case let .command(text, edited): return command(text, userEdited: edited)
        case let .approve(edited): return approve(userEdited: edited)
        case .archive: return finish(.archived)
        case let .retry(supplement): return retry(supplement: supplement)
        case .cancel: return finish(.idle)
        }
    }

    // MARK: - 단계별 처리

    private mutating func start(_ input: Input, _ snapshot: DocumentSnapshot) -> [Effect] {
        guard phase == .idle || isFinished else { return [] }
        self.input = input
        self.snapshot = snapshot
        commands = []
        careerRequests = []
        // 분석이 이미 있으면 분석 요청을 건너뛴다 (ANL-009)
        return snapshot.analysisDone ? requestDraft() : requestAnalysis()
    }

    private mutating func filesChanged(_ snapshot: DocumentSnapshot) -> [Effect] {
        self.snapshot = snapshot
        switch phase {
        case .analyzing where snapshot.analysisDone:
            return requestDraft()
        case .drafting where isNewer(snapshot.draftModified), .commanding where isNewer(snapshot.draftModified):
            return draftArrived(snapshot)
        case .generatingPDF where snapshot.pdfIsCurrent && isNewer(snapshot.pdfModified):
            return finish(.completed)
        default:
            return []
        }
    }

    private mutating func draftArrived(_ snapshot: DocumentSnapshot) -> [Effect] {
        guard let draft = snapshot.draft else { return [] }
        if case let .commanding(id) = phase { mark(id, .completed) }
        let opening = phase != .reviewing && !isCommanding
        phase = .reviewing
        return opening ? [.openReview(draft)] : []
    }

    private mutating func replied(_ reply: SessionReply) -> [Effect] {
        guard let id = currentRequestID, reply.id == id else { return careerEffect(reply) }
        var effects = careerEffect(reply)
        switch (phase, reply.outcome) {
        case (.commanding, .failed):
            // 명령 실패: 잠금을 풀고 내용은 그대로 둔다 (DOC-026)
            mark(id, .failed(reply.reason ?? "세션이 실패를 알림"))
            phase = .reviewing
        case (_, .failed):
            effects += fail(reply.reason ?? "세션이 실패를 알림", missing: reply.missing)
        case (_, .completed):
            // 회신은 보조 신호. 결과 파일이 없으면 완료로 보지 않는다
            if let snapshot { effects += filesChanged(snapshot) }
        }
        return effects
    }

    private mutating func command(_ text: String, userEdited: Bool) -> [Effect] {
        // 처리 중에는 새 명령을 받지 않는다 (DOC-027)
        guard phase == .reviewing, let input, let draft = snapshot?.draft,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let id = makeID()
        commands.append(Command(id: id, text: text, status: .running))
        baseline = snapshot?.draftModified
        phase = .commanding(requestID: id)
        let request = SessionRequest.edit(
            company: input.company, kind: input.kind, draftPath: draft.path, command: text, userEdited: userEdited
        )
        return [.send(request, id: id)]
    }

    private mutating func approve(userEdited: Bool) -> [Effect] {
        guard phase == .reviewing, let input, let draft = snapshot?.draft else { return [] }
        return requestPDF(input, draft: draft, userEdited: userEdited)
    }

    private mutating func retry(supplement: String?) -> [Effect] {
        guard case let .failed(failure) = phase, let input else { return [] }
        switch failure.step {
        case .analysis: return requestAnalysis(supplement: supplement)
        case .draft: return requestDraft()
        case .pdf:
            guard let draft = snapshot?.draft else { return requestDraft() }
            return requestPDF(input, draft: draft, userEdited: false)
        }
    }

    // MARK: - 요청 보내기

    private mutating func requestAnalysis(supplement: String? = nil) -> [Effect] {
        guard let input else { return [] }
        let id = makeID()
        phase = .analyzing(requestID: id)
        let request = SessionRequest.analysis(
            company: input.company, platform: input.platform, url: input.url,
            postingText: input.postingText, supplement: supplement
        )
        return [.send(request, id: id)]
    }

    private mutating func requestDraft() -> [Effect] {
        guard let input else { return [] }
        let id = makeID()
        baseline = snapshot?.draftModified
        phase = .drafting(requestID: id)
        let request: SessionRequest = switch input.kind {
        case .resume:
            .resumeDraft(company: input.company, url: input.url, postingText: input.postingText)
        case .coverLetter:
            .coverLetterDraft(
                company: input.company, url: input.url, postingText: input.postingText, questions: input.questions
            )
        }
        return [.send(request, id: id)]
    }

    private mutating func requestPDF(_ input: Input, draft: URL, userEdited: Bool) -> [Effect] {
        let id = makeID()
        baseline = snapshot?.pdfModified
        phase = .generatingPDF(requestID: id)
        let request = SessionRequest.pdf(
            company: input.company, kind: input.kind, draftPath: draft.path, userEdited: userEdited
        )
        return [.send(request, id: id)]
    }

    // MARK: - 도움

    private var currentRequestID: String? {
        switch phase {
        case let .analyzing(id), let .drafting(id), let .commanding(id), let .generatingPDF(id): id
        default: nil
        }
    }

    private var currentStep: Step {
        switch phase {
        case .analyzing: .analysis
        case .generatingPDF: .pdf
        default: .draft
        }
    }

    private var isCommanding: Bool {
        if case .commanding = phase { return true }
        return false
    }

    private var isFinished: Bool {
        switch phase {
        case .completed, .failed, .archived: true
        default: false
        }
    }

    private func isNewer(_ date: Date?) -> Bool {
        guard let date else { return false }
        return baseline.map { date > $0 } ?? true
    }

    private mutating func fail(_ reason: String, missing: [String]) -> [Effect] {
        phase = .failed(Failure(step: currentStep, reason: reason, missing: missing))
        return [.releaseLock]
    }

    private mutating func finish(_ end: Phase) -> [Effect] {
        guard phase != .idle || end != .idle else { return [] }
        phase = end
        return [.releaseLock]
    }

    private mutating func careerEffect(_ reply: SessionReply) -> [Effect] {
        guard let block = reply.careerDBRequest, !careerRequests.contains(block) else { return [] }
        careerRequests.append(block)
        return [.showCareerRequest(block)]
    }

    private mutating func mark(_ id: String, _ status: DocumentCommandStatus) {
        guard let index = commands.firstIndex(where: { $0.id == id }) else { return }
        commands[index].status = status
    }

    private mutating func makeID() -> String {
        defer { nextID += 1 }
        return "\(idPrefix)-\(nextID)"
    }
}

/// 수정 명령 상태 (처리 중 → 완료는 초안 파일 변경 감지 후에만, DOC-020)
public enum DocumentCommandStatus: Equatable, Sendable {
    case running, completed, failed(String)
}
