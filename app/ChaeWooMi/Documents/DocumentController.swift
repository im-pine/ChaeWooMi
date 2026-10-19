import AppKit
import ChaeWooMiCore
import Foundation
import Observation

/// 문서 · 분석 요청을 진행한다. 판단은 Core `DocumentWorkflow` · `AnalysisWorkflow`가 하고,
/// 여기서는 그 효과(세션 요청 · 검토 모달 · 잠금 해제)를 실행하고 볼트 변화 · 회신을 다시 넣는다.
/// 이력서 · 자소서는 각자의 상태 기계 · 검토 모달로 함께 진행한다 (사용자 요청 2026-10-19)
@MainActor
@Observable
final class DocumentController {
    private(set) var workflows = Dictionary(
        uniqueKeysWithValues: DocumentKind.allCases.map { ($0, DocumentWorkflow()) }
    )
    private(set) var analysis = AnalysisWorkflow()
    /// 종류별 마지막 문서 작업
    private(set) var activeJobs: [DocumentKind: DocumentJob] = [:]
    /// 세션 꺼짐 등으로 보내지 못한 이유 (AGT-004)
    private(set) var notice: String?

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let sessions: SessionHub
    @ObservationIgnored private let cards: CardStore
    @ObservationIgnored private let lock = DocumentJobLock()
    @ObservationIgnored private var reviewWindows: [DocumentKind: ReviewWindowController] = [:]
    @ObservationIgnored lazy var questionsWindow = QuestionsWindowController(controller: self)
    @ObservationIgnored private var analysisCompany: String?

    init(settings: AppSettings, sessions: SessionHub, cards: CardStore) {
        self.settings = settings
        self.sessions = sessions
        self.cards = cards
    }

    func workflow(_ kind: DocumentKind) -> DocumentWorkflow {
        workflows[kind] ?? DocumentWorkflow()
    }

    private func reviewWindow(_ kind: DocumentKind) -> ReviewWindowController {
        if let window = reviewWindows[kind] { return window }
        let window = ReviewWindowController(controller: self, kind: kind)
        reviewWindows[kind] = window
        return window
    }

    // MARK: - 시작

    /// 이력서 · 자소서 요청 (분석이 없으면 분석부터, ANL-004)
    func startDocument(_ kind: DocumentKind, questions: [CoverLetterQuestion] = []) {
        guard let input = documentInput(kind, questions: questions), let layout = cards.loaded?.layout else { return }
        let job = DocumentJob(company: input.company, kind: kind)
        Task {
            switch await lock.acquire(job) {
            case .granted:
                activeJobs[kind] = job
                notice = nil
                workflows[kind] = DocumentWorkflow()
                let snapshot = DocumentSnapshot.read(kind, company: input.company, layout: layout)
                // 다른 문서가 이 회사 분석을 이미 요청했으면 분석을 또 보내지 않고 함께 기다린다
                if let analysisID = pendingAnalysis(company: input.company, besides: kind) {
                    run(kind, .join(input, snapshot, analysisID: analysisID))
                } else {
                    run(kind, .start(input, snapshot))
                }
            case .alreadyRunning:
                break
            case let .busy(other):
                notice = "\(other.company) \(label(other.kind)) 작업이 끝난 뒤 시작할 수 있습니다"
            }
        }
    }

    /// 초안 있음 · 완료 아이콘: 세션 요청 없이 검토 모달 (완료한 문서도 더 고친다)
    func reopenDraft(_ kind: DocumentKind) {
        guard let input = documentInput(kind, questions: []), let layout = cards.loaded?.layout else { return }
        // PDF만 있고 초안 .md가 없으면 모달에 띄울 원고가 없다 (잠금을 잡기 전에 알린다)
        guard DocumentSnapshot.read(kind, company: input.company, layout: layout).draft != nil else {
            notice = "수정할 초안(.md)이 없습니다"
            return
        }
        notice = nil
        let job = DocumentJob(company: input.company, kind: kind)
        Task {
            switch await lock.acquire(job) {
            case .granted: break
            case .alreadyRunning:
                // 모달을 닫았거나 다른 앱으로 가려진 뒤 다시 누름 → 이어지던 검토 모달을 다시 앞으로
                if workflow(kind).phase == .reviewing { reviewWindow(kind).reshow() }
                return
            case .busy: return
            }
            activeJobs[kind] = job
            workflows[kind] = DocumentWorkflow()
            run(kind, .reopen(input, DocumentSnapshot.read(kind, company: input.company, layout: layout)))
        }
    }

    /// 공고 분석 아이콘 (ANL-001). 이미 분석돼 있으면 요청하지 않는다
    func startAnalysis() {
        guard let page = cards.model.page, let company = cards.confirmedCompany else { return }
        analysisCompany = company
        let input = AnalysisWorkflow.Input(
            company: company, platform: platformLabel(page.site), url: page.url, postingText: page.postingText,
            postingPath: settings.vaultPaths.postingFile(company: company)?.path
        )
        if let request = analysis.start(input, analysisDone: analysisDone(company)) {
            send(request, id: analysis.requestID ?? "")
        }
    }

    func retryAnalysis(supplement: String?) {
        if let request = analysis.retry(supplement: supplement) { send(request, id: analysis.requestID ?? "") }
    }

    // MARK: - 검토 모달에서

    func command(_ kind: DocumentKind, _ text: String, userEdited: Bool) {
        run(kind, .command(text, userEdited: userEdited))
    }

    func approve(_ kind: DocumentKind, userEdited: Bool) { run(kind, .approve(userEdited: userEdited)) }
    func archive(_ kind: DocumentKind) { run(kind, .archive) }
    func retry(_ kind: DocumentKind, supplement: String? = nil) { run(kind, .retry(supplement: supplement)) }

    // MARK: - 바깥 신호

    /// 볼트 파일이 바뀜
    func filesChanged() {
        if let company = analysisCompany { analysis.filesChanged(analysisDone: analysisDone(company)) }
        guard let layout = cards.loaded?.layout else { return }
        for (kind, job) in activeJobs {
            run(kind, .files(DocumentSnapshot.read(kind, company: job.company, layout: layout)))
        }
    }

    func received(_ reply: SessionReply) {
        // 회신이 FSEvents보다 먼저 올 수 있어, 판정 전에 볼트를 다시 읽는다
        filesChanged()
        if reply.id == analysis.requestID, let company = analysisCompany {
            analysis.replied(reply, analysisDone: analysisDone(company), postingExists: postingExists(company))
        }
        for kind in activeJobs.keys { run(kind, .reply(reply)) }
    }

    // MARK: - 아이콘 상태

    /// 진행 중인 아이콘과 그 단계 이름 (APP-012 덮어쓰기, 초안 작성 중 · PDF 만드는 중 등을 구분)
    var running: [TaskKind: String] {
        let analyzing = DocumentWorkflow.analysisProgressLabel
        var steps: [TaskKind: String] = analysis.requestID == nil ? [:] : [.analysis: analyzing]
        for kind in activeJobs.keys {
            let phase = workflow(kind).phase
            guard let step = DocumentWorkflow.progressLabel(phase) else { continue }
            if case .analyzing = phase { steps[.analysis] = analyzing }
            steps[taskKind(kind)] = step
        }
        return steps
    }

    var failures: [TaskKind: String] {
        var map: [TaskKind: String] = [:]
        if case let .failed(reason, missing) = analysis.phase { map[.analysis] = Self.describe(reason, missing) }
        for kind in activeJobs.keys {
            if case let .failed(failure) = workflow(kind).phase {
                map[taskKind(kind)] = Self.describe(failure.reason, failure.missing)
            }
        }
        return map
    }

    // MARK: - 내부

    private func run(_ kind: DocumentKind, _ event: DocumentWorkflow.Event) {
        var workflow = workflow(kind)
        let before = workflow.phase
        let effects = workflow.handle(event)
        workflows[kind] = workflow
        defer { openPDFIfFinished(kind, after: before) }
        for effect in effects {
            switch effect {
            case let .send(request, id): send(request, id: id)
            case let .openReview(url): reviewWindow(kind).show(draft: url, layout: cards.loaded?.layout)
            case .showCareerRequest: break // 모달이 workflow.careerRequests를 보인다
            case .releaseLock: release(kind)
            }
        }
        reviewWindow(kind).refresh()
    }

    /// PDF 생성 단계에서 완료로 바뀌면 그 PDF를 연다 (사용자 요청 2026-10-18)
    private func openPDFIfFinished(_ kind: DocumentKind, after before: DocumentWorkflow.Phase) {
        let workflow = workflow(kind)
        guard DocumentWorkflow.finishedPDF(from: before, to: workflow.phase), let pdf = workflow.snapshot?.pdf else {
            return
        }
        NSWorkspace.shared.open(pdf)
    }

    /// 같은 회사의 다른 문서가 기다리는 분석 요청 id
    private func pendingAnalysis(company: String, besides kind: DocumentKind) -> String? {
        for (other, job) in activeJobs where other != kind && job.company == company {
            if case let .analyzing(id) = workflow(other).phase { return id }
        }
        return nil
    }

    private func send(_ request: SessionRequest, id: String) {
        let roster = settings.sessionRoster
        Task {
            guard let refusal = await sessions.send(request, id: id, roster: roster) else { return }
            notice = refusal
            if id == analysis.requestID { analysis.cancel(); return }
            // 그 요청을 기다리는 문서 모두 (함께 기다리던 분석 포함)
            for kind in activeJobs.keys where workflow(kind).currentRequestID == id { run(kind, .cancel) }
        }
    }

    private func release(_ kind: DocumentKind) {
        guard let job = activeJobs[kind] else { return }
        Task { await lock.release(job) }
    }

    private func documentInput(_ kind: DocumentKind, questions: [CoverLetterQuestion]) -> DocumentWorkflow.Input? {
        guard let page = cards.model.page, let company = cards.confirmedCompany else { return nil }
        // 설정의 저장 규칙으로 결과 파일 경로를 정해 요청에 넣는다 (세션과 같은 파일을 본다)
        let paths = settings.vaultPaths
        return DocumentWorkflow.Input(
            kind: kind, company: company, platform: platformLabel(page.site), url: page.url,
            postingText: page.postingText, questions: questions,
            postingPath: paths.postingFile(company: company)?.path,
            draftPath: paths.draftFile(kind, company: company)?.path
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
