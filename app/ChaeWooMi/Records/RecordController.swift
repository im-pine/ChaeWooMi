import ChaeWooMiCore
import Foundation
import Observation

/// 지원 기록을 진행한다. 판단은 Core `RecordWorkflow`가 하고, 여기서는 1초 타이머 · 세션 요청 ·
/// 12.0 재조회를 실행한다. 채우미는 12.0을 쓰지 않는다 (HIS-005).
@MainActor
@Observable
final class RecordController {
    private(set) var workflow = RecordWorkflow()
    /// 지원 완료 카드를 띄움 (감지 · 직접 기록의 진행 · 결과)
    private(set) var presenting = false
    /// 카드에서 고쳐 쓸 폼 (회사를 확정하지 못했거나 실패했을 때)
    private(set) var form: Submission?
    /// 세션 꺼짐 등으로 보내지 못한 이유 (AGT-004)
    private(set) var notice: String?

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let sessions: SessionHub
    @ObservationIgnored private let cards: CardStore
    @ObservationIgnored private var timer: Task<Void, Never>?
    /// 마지막으로 기록하려던 값 (실패 뒤 고쳐 쓰기)
    @ObservationIgnored private var last: Submission?

    init(settings: AppSettings, sessions: SessionHub, cards: CardStore) {
        self.settings = settings
        self.sessions = sessions
        self.cards = cards
    }

    // MARK: - 시작

    /// 지원 완료 화면 감지 (HIS-017). 회사가 확정되면 5초 카운트다운, 아니면 폼으로 먼저 교정 (HIS-002)
    func detected(_ page: JobPage) {
        guard !workflow.isBusy else { return }
        notice = nil
        presenting = true
        let lookup = cards.lookup(page.companies)
        var submission = Submission(
            company: page.companies.first ?? "", role: Self.role(from: page.title) ?? "",
            platform: platformLabel(page.site), submitted: .today()
        )
        last = submission
        switch lookup {
        case let .caution(company, _), let .clear(company, _):
            submission.company = company
            last = submission
            form = nil
            run(.detected(submission))
            startTimer()
        default:
            form = submission
        }
    }

    /// 상세보기의 지원 완료 기록 폼 초기값 (HIS-001 · HIS-003)
    func draft(company: String) -> Submission {
        let page = cards.model.page
        return Submission(
            company: company, role: page.flatMap { Self.role(from: $0.title) } ?? "",
            platform: page.map { platformLabel($0.site) } ?? "", submitted: .today()
        )
    }

    func confirm(_ submission: Submission) {
        notice = nil
        last = submission
        run(.confirm(submission, today: .today()))
        // 폼 값이 틀리면 그 폼에 문제를 보이고(카드 폼이면 카드에 남김), 요청이 나갈 때만 카드로 진행을 보인다
        if workflow.problem != nil {
            if presenting { form = submission }
            return
        }
        form = nil
        presenting = true
    }

    /// 카운트다운 안의 취소: 기록하지 않는다
    func cancel() {
        run(.cancel)
        dismiss()
    }

    /// 카운트다운 카드의 기록 버튼: 기다리지 않고 바로
    func recordNow() {
        guard case let .countdown(_, submission) = workflow.phase else { return }
        confirm(submission)
    }

    /// 실패 뒤 고쳐서 다시
    func edit() {
        form = last ?? draft(company: cards.confirmedCompany ?? "")
    }

    func dismiss() {
        guard !isRecording else { return }
        timer?.cancel()
        presenting = false
        form = nil
        notice = nil
        if !workflow.isBusy { workflow = RecordWorkflow() }
    }

    // MARK: - 바깥 신호

    /// 12.0이 바뀜 (CardStore가 다시 읽은 뒤)
    func filesChanged() {
        run(.records(records))
    }

    func received(_ reply: SessionReply) {
        // 회신이 FSEvents보다 먼저 올 수 있어 12.0을 다시 읽고 판정한다 (HIS-013)
        cards.reloadVault()
        run(.reply(reply, records: records))
    }

    // MARK: - 내부

    private var isRecording: Bool {
        if case .recording = workflow.phase { return true }
        return false
    }

    private var records: [ApplicationRecord] {
        cards.loaded?.result.records ?? []
    }

    private func run(_ event: RecordWorkflow.Event) {
        for case let .send(request, id) in workflow.handle(event) {
            send(request, id: id)
        }
        if !isCountingDown { timer?.cancel() }
    }

    private var isCountingDown: Bool {
        if case .countdown = workflow.phase { return true }
        return false
    }

    private func startTimer() {
        timer?.cancel()
        timer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self, isCountingDown else { return }
                run(.tick)
            }
        }
    }

    private func send(_ request: SessionRequest, id: String) {
        let roster = settings.sessionRoster
        Task {
            guard let refusal = await sessions.send(request, id: id, roster: roster) else { return }
            notice = refusal
            form = last
            workflow = RecordWorkflow()
        }
    }

    private func platformLabel(_ site: String) -> String {
        SiteConfig.defaultConfig.sites.first { $0.id == site }?.label ?? site
    }

    /// `[가상전자(주)] 프론트엔드 개발자 채용` → `프론트엔드 개발자 채용` (앞 대괄호 회사명만 뗀다)
    static func role(from title: String?) -> String? {
        guard var text = title?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
        if text.hasPrefix("["), let end = text.firstIndex(of: "]") {
            text = String(text[text.index(after: end)...]).trimmingCharacters(in: .whitespaces)
        }
        return text.isEmpty ? nil : text
    }
}
