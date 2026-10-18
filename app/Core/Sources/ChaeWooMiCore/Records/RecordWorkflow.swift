import Foundation

/// 지원 기록 한 건: (지원 완료 감지 → 5초 카운트다운) 또는 직접 기록 폼 → JOB-ANALYSIS에 12.0 기록 요청 → 12.0 재조회 확인.
/// 채우미는 12.0을 쓰지 않는다 (HIS-005). 성공 표시는 다시 읽은 12.0에 기록이 보일 때만 한다 (HIS-013).
public struct RecordWorkflow: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case idle
        /// 지원 완료 화면 감지: 남은 초가 0이 되면 기록 요청, 그 전에 취소하면 기록하지 않음 (HIS-017)
        case countdown(remaining: Int, Submission)
        /// 기록 요청을 보내고 12.0 반영을 기다림
        case recording(requestID: String, company: String, submitted: CalendarDay)
        /// 12.0에서 확인함
        case recorded(company: String, submitted: CalendarDay)
        case failed(reason: String)
    }

    public enum Event: Equatable, Sendable {
        /// 지원 완료 화면 감지 (회사가 확정된 공고에서만)
        case detected(Submission)
        /// 1초 지남
        case tick
        case cancel
        /// 폼의 기록 버튼 · 카운트다운 카드의 기록 버튼 (HIS-001 · HIS-002)
        case confirm(Submission, today: CalendarDay)
        /// 12.0을 다시 읽음
        case records([ApplicationRecord])
        /// 세션 회신. 회신 전에 다시 읽은 12.0을 함께 넣는다
        case reply(SessionReply, records: [ApplicationRecord])
    }

    public enum Effect: Equatable, Sendable {
        case send(SessionRequest, id: String)
    }

    public static let countdownSeconds = 5

    public private(set) var phase: Phase = .idle
    /// 폼 값이 틀려 요청하지 않음 (폼에 표시)
    public private(set) var problem: Submission.Problem?
    private var nextID = 1
    private let idPrefix: String

    public init(idPrefix: String = "rec-" + UUID().uuidString.prefix(6).lowercased()) {
        self.idPrefix = idPrefix
    }

    public var isBusy: Bool {
        switch phase {
        case .countdown, .recording: true
        default: false
        }
    }

    public mutating func handle(_ event: Event, today: CalendarDay = .today()) -> [Effect] {
        switch event {
        case let .detected(submission):
            guard !isBusy else { return [] }
            problem = nil
            phase = .countdown(remaining: Self.countdownSeconds, submission)
            return []
        case .tick:
            return tick(today: today)
        case .cancel:
            guard case .countdown = phase else { return [] }
            phase = .idle
            return []
        case let .confirm(submission, day):
            if case .recording = phase { return [] }
            return submit(submission, today: day)
        case let .records(rows):
            return verify(rows, failIfMissing: false)
        case let .reply(reply, rows):
            return replied(reply, rows)
        }
    }

    private mutating func tick(today: CalendarDay) -> [Effect] {
        guard case let .countdown(remaining, submission) = phase else { return [] }
        guard remaining <= 1 else {
            phase = .countdown(remaining: remaining - 1, submission)
            return []
        }
        return submit(submission, today: today)
    }

    private mutating func submit(_ submission: Submission, today: CalendarDay) -> [Effect] {
        switch submission.request(today: today) {
        case let .failure(problem):
            self.problem = problem
            if case .countdown = phase { phase = .failed(reason: problem.message) }
            return []
        case let .success(request):
            guard case let .record(company, _, _, day) = request else { return [] }
            problem = nil
            let id = "\(idPrefix)-\(nextID)"
            nextID += 1
            phase = .recording(requestID: id, company: company, submitted: day)
            return [.send(request, id: id)]
        }
    }

    private mutating func replied(_ reply: SessionReply, _ rows: [ApplicationRecord]) -> [Effect] {
        guard case let .recording(id, _, _) = phase, reply.id == id else { return [] }
        if reply.outcome == .failed {
            phase = .failed(reason: reply.reason ?? "세션이 기록하지 못했습니다")
            return []
        }
        return verify(rows, failIfMissing: true)
    }

    /// 회사 행의 최근 제출일이 그 날이거나, 더 최근 지원이 있어 비고에 그 날이 남았으면 반영된 것
    private mutating func verify(_ rows: [ApplicationRecord], failIfMissing: Bool) -> [Effect] {
        guard case let .recording(_, company, day) = phase else { return [] }
        if case let .matched(_, matched) = CompanyMatcher.match(candidates: [company], records: rows),
           matched.contains(where: { $0.lastSubmitted == day || $0.note.contains(day.description) }) {
            phase = .recorded(company: company, submitted: day)
        } else if failIfMissing {
            phase = .failed(reason: "세션은 완료라고 했지만 12.0에서 기록을 찾지 못했습니다")
        }
        return []
    }
}
