import ChaeWooMiCore
import Foundation
import Observation

/// 문서 · 분석 요청을 진행한다. 판단은 Core `DocumentWorkflow` · `AnalysisWorkflow`가 하고,
/// 여기서는 그 효과(세션 요청 · 검토 모달 · 잠금 해제)를 실행하고 볼트 변화 · 회신을 다시 넣는다.
@MainActor
@Observable
final class DocumentController {
    private(set) var workflow = DocumentWorkflow()
    private(set) var analysis = AnalysisWorkflow()
    /// 지금 문서 작업 (이력서 · 자소서 중 하나, DOC-010)
    private(set) var activeJob: DocumentJob?
    /// 세션 꺼짐 등으로 보내지 못한 이유 (AGT-004)
    private(set) var notice: String?

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let sessions: SessionHub
    @ObservationIgnored private let cards: CardStore
    @ObservationIgnored private let lock = DocumentJobLock()
    @ObservationIgnored lazy var reviewWindow = ReviewWindowController(controller: self)
    @ObservationIgnored lazy var questionsWindow = QuestionsWindowController(controller: self)
    @ObservationIgnored private var analysisCompany: String?

    init(settings: AppSettings, sessions: SessionHub, cards: CardStore) {
        self.settings = settings
        self.sessions = sessions
        self.cards = cards
    }

    // MARK: - 시작

    /// 이력서 · 자소서 요청 (분석이 없으면 분석부터, ANL-004)
    func startDocument(_ kind: DocumentKind, questions: [CoverLetterQuestion] = []) {
        guard let input = documentInput(kind, questions: questions), let layout = cards.loaded?.layout else { return }
        let job = DocumentJob(company: input.company, kind: kind)
        Task {
            switch await lock.acquire(job) {
            case .granted:
                activeJob = job
                notice = nil
                workflow = DocumentWorkflow()
                run(workflow: .start(input, DocumentSnapshot.read(kind, company: input.company, layout: layout)))
            case .alreadyRunning:
                break
            case let .busy(other):
                notice = "\(label(other.kind)) 작업이 끝난 뒤 시작할 수 있습니다"
            }
        }
    }

    /// 초안 있음 아이콘: 세션 요청 없이 검토 모달
    func reopenDraft(_ kind: DocumentKind) {
        guard let input = documentInput(kind, questions: []), let layout = cards.loaded?.layout else { return }
        let job = DocumentJob(company: input.company, kind: kind)
        Task {
            guard await lock.acquire(job) == .granted else { return }
            activeJob = job
            workflow = DocumentWorkflow()
            run(workflow: .reopen(input, DocumentSnapshot.read(kind, company: input.company, layout: layout)))
        }
    }

    /// 공고 분석 아이콘 (ANL-001). 이미 분석돼 있으면 요청하지 않는다
    func startAnalysis() {
        guard let page = cards.model.page, let company = cards.confirmedCompany else { return }
        analysisCompany = company
        let input = AnalysisWorkflow.Input(
            company: company, platform: platformLabel(page.site), url: page.url, postingText: page.postingText
        )
        if let request = analysis.start(input, analysisDone: analysisDone(company)) {
            send(request, id: analysis.requestID ?? "")
        }
    }

    func retryAnalysis(supplement: String?) {
        if let request = analysis.retry(supplement: supplement) { send(request, id: analysis.requestID ?? "") }
    }

    // MARK: - 검토 모달에서

    func command(_ text: String, userEdited: Bool) { run(workflow: .command(text, userEdited: userEdited)) }
    func approve(userEdited: Bool) { run(workflow: .approve(userEdited: userEdited)) }
    func archive() { run(workflow: .archive) }
    func retry(supplement: String? = nil) { run(workflow: .retry(supplement: supplement)) }

    // MARK: - 바깥 신호

    /// 볼트 파일이 바뀜
    func filesChanged() {
        if let company = analysisCompany { analysis.filesChanged(analysisDone: analysisDone(company)) }
        guard let job = activeJob, let layout = cards.loaded?.layout else { return }
        run(workflow: .files(DocumentSnapshot.read(job.kind, company: job.company, layout: layout)))
    }

    func received(_ reply: SessionReply) {
        // 회신이 FSEvents보다 먼저 올 수 있어, 판정 전에 볼트를 다시 읽는다
        filesChanged()
        if reply.id == analysis.requestID, let company = analysisCompany {
            analysis.replied(reply, analysisDone: analysisDone(company), postingExists: postingExists(company))
        }
        run(workflow: .reply(reply))
    }

    // MARK: - 아이콘 상태

    /// 진행 중인 아이콘 (APP-012 덮어쓰기)
    var running: Set<TaskKind> {
        var kinds: Set<TaskKind> = analysis.requestID == nil ? [] : [.analysis]
        guard let job = activeJob else { return kinds }
        switch workflow.phase {
        case .analyzing: kinds.formUnion([.analysis, taskKind(job.kind)])
        case .drafting, .commanding, .generatingPDF: kinds.insert(taskKind(job.kind))
        default: break
        }
        return kinds
    }

    var failures: [TaskKind: String] {
        var map: [TaskKind: String] = [:]
        if case let .failed(reason, missing) = analysis.phase { map[.analysis] = Self.describe(reason, missing) }
        if let job = activeJob, case let .failed(failure) = workflow.phase {
            map[taskKind(job.kind)] = Self.describe(failure.reason, failure.missing)
        }
        return map
    }

    /// 다른 문서가 진행 중이면 이 문서는 시작할 수 없다 (DOC-010)
    func blockedReason(for kind: TaskKind) -> String? {
        guard let job = activeJob, kind != .analysis, taskKind(job.kind) != kind, isActive else { return nil }
        return "\(label(job.kind)) 작업 중에는 시작할 수 없습니다"
    }

    // MARK: - 내부

    private func run(workflow event: DocumentWorkflow.Event) {
        for effect in workflow.handle(event) {
            switch effect {
            case let .send(request, id): send(request, id: id)
            case let .openReview(url): reviewWindow.show(draft: url, layout: cards.loaded?.layout)
            case .showCareerRequest: break // 모달이 workflow.careerRequests를 보인다
            case .releaseLock: release()
            }
        }
        reviewWindow.refresh()
    }

    private func send(_ request: SessionRequest, id: String) {
        let roster = settings.sessionRoster
        Task {
            guard let refusal = await sessions.send(request, id: id, roster: roster) else { return }
            notice = refusal
            if id == analysis.requestID { analysis.cancel() } else { run(workflow: .cancel) }
        }
    }

    private func release() {
        guard let job = activeJob else { return }
        Task { await lock.release(job) }
    }

    private var isActive: Bool {
        switch workflow.phase {
        case .idle, .completed, .failed, .archived: false
        default: true
        }
    }

    private func documentInput(_ kind: DocumentKind, questions: [CoverLetterQuestion]) -> DocumentWorkflow.Input? {
        guard let page = cards.model.page, let company = cards.confirmedCompany else { return nil }
        return DocumentWorkflow.Input(
            kind: kind, company: company, platform: platformLabel(page.site), url: page.url,
            postingText: page.postingText, questions: questions
        )
    }

    private func postingExists(_ company: String) -> Bool {
        cards.folders(for: company).map(TaskStateRule.postingExists) ?? false
    }

    private func analysisDone(_ company: String) -> Bool {
        guard let folders = cards.folders(for: company) else { return false }
        return TaskStateRule.fileState(.analysis, folders: folders) == .completed
    }

    private func platformLabel(_ site: String) -> String {
        SiteConfig.defaultConfig.sites.first { $0.id == site }?.label ?? site
    }

    private func taskKind(_ kind: DocumentKind) -> TaskKind {
        kind == .resume ? .resume : .coverLetter
    }

    private func label(_ kind: DocumentKind) -> String {
        kind == .resume ? "이력서" : "자기소개서"
    }

    private static func describe(_ reason: String, _ missing: [String]) -> String {
        missing.isEmpty ? reason : "\(reason) (누락: \(missing.joined(separator: ", ")))"
    }
}
