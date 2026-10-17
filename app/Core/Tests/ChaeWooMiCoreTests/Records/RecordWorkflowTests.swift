import Foundation
import Testing
@testable import ChaeWooMiCore

private let today = CalendarDay(year: 2026, month: 10, day: 17)!

private func submission(_ day: CalendarDay = today) -> Submission {
    Submission(company: "가상전자(주)", role: "프론트엔드 개발자", platform: "원티드", submitted: day)
}

/// 기록 요청을 가짜 세션에 돌리고, 회신 전에 12.0을 다시 읽어 넣는다 (앱의 RecordController가 하는 일)
private func run(_ effects: [RecordWorkflow.Effect], _ flow: inout RecordWorkflow, _ session: FakeSession) throws {
    for case let .send(request, id) in effects {
        let reply = try session.handle(request, id: id)
        _ = flow.handle(.reply(reply, records: try session.records()), today: today)
    }
}

private func lookup(_ session: FakeSession) throws -> CompanyLookup {
    CompanyLookup.resolve(candidates: ["가상전자(주)"], status: .success(try session.records()), today: today)
}

@Suite("지원 기록 통합 흐름 (가상 볼트 + 가짜 세션)")
struct RecordIntegrationTests {
    @Test("공고 → 재지원 주의 → 문서 요청 → 승인 → 지원 완료 감지 → 5초 → 12.0 기록 요청 → 재조회")
    func applyEndToEnd() throws {
        let session = try FakeSession()
        defer { withExtendedLifetime(session) {} }
        try session.vault.write("12 JobOpening/12.0 지원 현황.md", """
        | 회사 | 직무 | 최근 제출일 | 재지원 가능 | 상태 | 비고 |
        |---|---|---|---|---|---|
        | 가상전자(주) | 백엔드 개발자 | 2026-09-01 | 2027-09-01 | 서류 탈락 |  |
        """)

        // 공고 → 재지원 주의 (MAT-006)
        guard case let .caution(_, before) = try lookup(session) else {
            Issue.record("재지원 주의가 아님")
            return
        }
        #expect(before.lastSubmitted == CalendarDay(year: 2026, month: 9, day: 1))

        // 문서 요청 → 분석 선행 → 초안 → 승인 → PDF → 완료
        var documents = WorkflowDriver(session: session, company: "가상전자(주)", kind: .resume)
        try documents.send(.start(DocumentWorkflow.Input(
            kind: .resume, company: "가상전자(주)", platform: "원티드",
            url: "https://www.wanted.co.kr/wd/300001", postingText: "주요업무: React", questions: []
        ), documents.snapshot()))
        try documents.send(.approve(userEdited: false))
        #expect(documents.workflow.phase == .completed)
        // 문서 완성만으로는 기록하지 않는다 (HIS-001 · QA-047)
        #expect(!session.received.contains { $0.kindLabel == "지원 기록" })

        // 지원 완료 화면 감지 → 5초 카운트다운 → 기록 요청 (HIS-017)
        var flow = RecordWorkflow(idPrefix: "r")
        _ = flow.handle(.detected(submission()), today: today)
        for second in 1..<RecordWorkflow.countdownSeconds {
            #expect(flow.handle(.tick, today: today).isEmpty, "\(second)초")
        }
        let effects = flow.handle(.tick, today: today)
        #expect(effects == [.send(.record(
            company: "가상전자(주)", role: "프론트엔드 개발자", platform: "원티드", submitted: today
        ), id: "r-1")])
        try run(effects, &flow, session)

        // 재조회: 기록이 보여야 성공, 재지원 주의 라벨도 새 날짜로 (HIS-013 · QA-049 · QA-052)
        #expect(flow.phase == .recorded(company: "가상전자(주)", submitted: today))
        guard case let .caution(_, after) = try lookup(session) else {
            Issue.record("재지원 주의가 아님")
            return
        }
        #expect(after.lastSubmitted == today)
        #expect(after.reapplyFrom == CalendarDay(year: 2027, month: 10, day: 17))
        let row = try #require(try session.records().first)
        #expect(row.note.contains("이전 지원 2026-09-01"))
        #expect(try session.records().count == 1)
    }

    @Test("카운트다운 안에 취소하면 기록하지 않고 12.0도 그대로다 (QA-064)")
    func cancelWithinCountdown() throws {
        let session = try FakeSession()
        defer { withExtendedLifetime(session) {} }
        let before = try String(contentsOf: session.layout.statusFile, encoding: .utf8)
        var flow = RecordWorkflow(idPrefix: "r")
        _ = flow.handle(.detected(submission()), today: today)
        _ = flow.handle(.tick, today: today)
        _ = flow.handle(.cancel, today: today)
        let later = (0..<10).flatMap { _ in flow.handle(.tick, today: today) }

        #expect(later.isEmpty)
        #expect(flow.phase == .idle)
        #expect(session.received.isEmpty)
        #expect(try String(contentsOf: session.layout.statusFile, encoding: .utf8) == before)
    }

    @Test("직접 기록: 감지되지 않은 지원을 폼에서 과거 날짜로 기록하면 그 날짜가 반영된다 (HIS-001 · HIS-004 · QA-048 · QA-051)")
    func manualPastDate() throws {
        let session = try FakeSession()
        defer { withExtendedLifetime(session) {} }
        var flow = RecordWorkflow(idPrefix: "r")
        let past = CalendarDay(year: 2026, month: 3, day: 2)!

        try run(flow.handle(.confirm(submission(past), today: today), today: today), &flow, session)

        #expect(flow.phase == .recorded(company: "가상전자(주)", submitted: past))
        #expect(try session.records().first?.lastSubmitted == past)
    }

    @Test("세션이 완료라고 해도 12.0에 기록이 없으면 성공으로 보이지 않는다 (HIS-013)")
    func replyWithoutRow() throws {
        let session = try FakeSession()
        defer { withExtendedLifetime(session) {} }
        session.skipsRecordWrite = true
        var flow = RecordWorkflow(idPrefix: "r")

        try run(flow.handle(.confirm(submission(), today: today), today: today), &flow, session)

        #expect(flow.phase == .failed(reason: "세션은 완료라고 했지만 12.0에서 기록을 찾지 못했습니다"))
    }

    @Test("세션이 실패를 알리면 그 사유로 실패")
    func sessionFailure() throws {
        let session = try FakeSession()
        defer { withExtendedLifetime(session) {} }
        session.failing["지원 기록"] = ("12.0이 잠겨 있음", [])
        var flow = RecordWorkflow(idPrefix: "r")

        try run(flow.handle(.confirm(submission(), today: today), today: today), &flow, session)

        #expect(flow.phase == .failed(reason: "12.0이 잠겨 있음"))
    }
}

@Suite("지원 기록 상태 기계 · 제출 폼")
struct RecordWorkflowTests {
    @Test("회신보다 12.0 변경이 먼저 와도 반영을 확인하면 기록됨")
    func rowBeforeReply() {
        var flow = RecordWorkflow(idPrefix: "r")
        _ = flow.handle(.confirm(submission(), today: today), today: today)
        let row = ApplicationRecord(
            company: "가상전자(주)", role: "", lastSubmitted: today, reapplyFrom: nil, status: "", note: ""
        )
        _ = flow.handle(.records([]), today: today)
        #expect(flow.phase == .recording(requestID: "r-1", company: "가상전자(주)", submitted: today))
        _ = flow.handle(.records([row]), today: today)
        #expect(flow.phase == .recorded(company: "가상전자(주)", submitted: today))
    }

    @Test("기록 중에는 다시 요청하지 않고, 다른 요청의 회신은 무시한다")
    func ignoresDuplicates() throws {
        var flow = RecordWorkflow(idPrefix: "r")
        #expect(flow.handle(.confirm(submission(), today: today), today: today).count == 1)
        #expect(flow.handle(.confirm(submission(), today: today), today: today).isEmpty)
        #expect(flow.handle(.detected(submission()), today: today).isEmpty)
        let other = try #require(SessionReply.parse("[채우미 회신] id=zzz 결과=실패\n사유: x"))
        _ = flow.handle(.reply(other, records: []), today: today)
        #expect(flow.isBusy)
    }

    @Test("제출일 기본값은 Asia/Seoul 기준 오늘: UTC로 전날 밤이어도 서울 날짜 (HIS-003 · QA-050)")
    func seoulToday() throws {
        // 2026-10-16 15:30 UTC = 2026-10-17 00:30 KST
        let now = try #require(ISO8601DateFormatter().date(from: "2026-10-16T15:30:00Z"))
        let utc = try #require(TimeZone(identifier: "UTC"))
        #expect(CalendarDay.today(now: now).description == "2026-10-17")
        #expect(CalendarDay.today(now: now, timeZone: utc).description == "2026-10-16")
    }

    @Test("잘못된 날짜 · 미래 날짜 · 빈 회사명은 거절하고 요청하지 않는다 (HIS-004)", arguments: [
        ("가상전자(주)", "2026/10/01", Submission.Problem.dateFormat),
        ("가상전자(주)", "2026-02-30", .dateFormat),
        ("가상전자(주)", "2026-10-01 이후", .dateFormat),
        ("가상전자(주)", "2026-10-18", .futureDate),
        ("  ", "2026-10-01", .noCompany)
    ])
    func rejects(company: String, date: String, problem: Submission.Problem) {
        var form = submission()
        form.company = company
        form.submitted = date
        var flow = RecordWorkflow(idPrefix: "r")
        #expect(flow.handle(.confirm(form, today: today), today: today).isEmpty)
        #expect(flow.problem == problem)
        #expect(flow.phase == .idle)
    }

    @Test("카운트다운이 끝났는데 폼 값이 틀리면 요청하지 않고 실패로 알린다")
    func countdownWithBadForm() {
        var form = submission()
        form.company = ""
        var flow = RecordWorkflow(idPrefix: "r")
        _ = flow.handle(.detected(form), today: today)
        let effects = (0..<RecordWorkflow.countdownSeconds).flatMap { _ in flow.handle(.tick, today: today) }
        #expect(effects.isEmpty)
        #expect(flow.phase == .failed(reason: Submission.Problem.noCompany.message))
    }
}
