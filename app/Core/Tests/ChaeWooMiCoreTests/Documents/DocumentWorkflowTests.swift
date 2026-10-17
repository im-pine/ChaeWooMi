import Foundation
import Testing
@testable import ChaeWooMiCore

private func input(_ kind: DocumentKind, _ questions: [CoverLetterQuestion] = []) -> DocumentWorkflow.Input {
    DocumentWorkflow.Input(
        kind: kind, company: "가상전자(주)", platform: "원티드",
        url: "https://www.wanted.co.kr/wd/300001", postingText: "주요업무: React", questions: questions
    )
}

@Suite("문서 제작 통합 흐름 (가상 볼트 + 가짜 세션)")
struct DocumentWorkflowIntegrationTests {
    @Test("이력서: 분석 선행 → 초안 → 편집 잠금 · 수정 → 승인 → PDF 감지 → 완료")
    func resumeEndToEnd() throws {
        let session = try FakeSession()
        defer { withExtendedLifetime(session) {} }
        var driver = WorkflowDriver(session: session, company: "가상전자(주)", kind: .resume)

        // 문서 요청 → 분석이 없으니 분석부터 (ANL-004), 분석 파일이 생기면 초안 요청 → 초안이 생기면 모달
        try driver.send(.start(input(.resume), driver.snapshot()))
        #expect(session.received.map(\.kindLabel) == ["공고 분석", "이력서 초안"])
        #expect(driver.workflow.phase == .reviewing)
        #expect(driver.opened.map(\.lastPathComponent) == ["테스터_이력서_가상전자.md"])
        // 승인 전에는 PDF가 없다 (DOC-022)
        #expect(driver.snapshot().pdf == nil)

        // 사용자가 직접 고친 뒤 수정 명령 → 처리 중 잠금, 끝나면 풀림 (DOC-018 · DOC-026)
        let draft = try #require(driver.snapshot().draft)
        try session.userEdits(draft, append: "사용자가 쓴 문장")
        var check = driver.workflow
        _ = check.handle(.files(driver.snapshot()))
        _ = check.handle(.command("요약을 줄여 주세요", userEdited: true))
        #expect(check.editingLocked)
        try driver.send(.files(driver.snapshot()))
        try driver.send(.command("요약을 줄여 주세요", userEdited: true))
        #expect(!driver.workflow.editingLocked)
        #expect(driver.workflow.commands.map(\.status) == [.completed])
        let edited = try String(contentsOf: draft, encoding: .utf8)
        #expect(edited.contains("사용자가 쓴 문장"))
        #expect(edited.contains("(수정: 요약을 줄여 주세요)"))
        if case let .edit(_, _, _, _, userEdited) = session.received[2] { #expect(userEdited) }

        // 승인 → PDF 생성 요청 → PDF가 초안보다 최신이면 완료 (DOC-025)
        try driver.send(.approve(userEdited: false))
        #expect(session.received.last?.kindLabel == "PDF 생성")
        #expect(driver.workflow.phase == .completed)
        #expect(driver.snapshot().pdfIsCurrent)
        #expect(driver.lockReleased == 1)
        let folders = CompanyFolders.find(company: "가상전자", in: session.layout)
        #expect(TaskStateRule.fileState(.resume, folders: folders) == .completed)
    }

    @Test("자소서: 분석이 있으면 바로 초안, 문항이 요청에 들어가고 CAREER-DB 반영 요청은 복사 카드로만 (DOC-031)")
    func coverLetterWithCareerCard() throws {
        let session = try FakeSession()
        defer { withExtendedLifetime(session) {} }
        session.careerRequest = "[CAREER-DB 반영 요청]\n- 대상: 가상 프로젝트\n- 내용: 새 경험"
        let analysis = SessionRequest.analysis(company: "가상전자(주)", platform: "원티드", url: "u", postingText: nil)
        _ = try session.handle(analysis, id: "pre")
        var driver = WorkflowDriver(session: session, company: "가상전자(주)", kind: .coverLetter)

        let questions = [CoverLetterQuestion(text: "지원 동기", limit: 500)]
        try driver.send(.start(input(.coverLetter, questions), driver.snapshot()))

        #expect(session.received.map(\.kindLabel) == ["공고 분석", "자소서 초안"])
        #expect(driver.workflow.phase == .reviewing)
        #expect(driver.careerCards == ["[CAREER-DB 반영 요청]\n- 대상: 가상 프로젝트\n- 내용: 새 경험"])
        #expect(!session.received.contains { $0.text(id: "x").contains("CAREER-DB") })
        let draft = try String(contentsOf: try #require(driver.snapshot().draft), encoding: .utf8)
        #expect(draft.contains("## 지원 동기"))
    }

    @Test("분석 실패면 누락 항목과 함께 실패로 멈추고 초안으로 넘어가지 않으며, 다시 시도하면 분석부터 (ANL-003 · AGT-008)")
    func analysisFailureAndRetry() throws {
        let session = try FakeSession()
        defer { withExtendedLifetime(session) {} }
        session.failing["공고 분석"] = ("필수 자격이 비어 있음", ["자격요건"])
        var driver = WorkflowDriver(session: session, company: "가상전자(주)", kind: .resume)

        try driver.send(.start(input(.resume), driver.snapshot()))
        guard case let .failed(failure) = driver.workflow.phase else {
            Issue.record("\(driver.workflow.phase)")
            return
        }
        #expect(failure.step == .analysis)
        #expect(failure.missing == ["자격요건"])
        #expect(!session.received.contains { $0.kindLabel == "이력서 초안" })

        session.failing = [:]
        try driver.send(.retry(supplement: "자격요건: TypeScript 2년"))
        #expect(session.received.map(\.kindLabel) == ["공고 분석", "공고 분석", "이력서 초안"])
        #expect(driver.workflow.phase == .reviewing)
    }

    @Test("PDF 생성 실패를 알리면 완료로 바꾸지 않고 실패로 둔다 (QA-042)")
    func pdfFailure() throws {
        let session = try FakeSession()
        defer { withExtendedLifetime(session) {} }
        var driver = WorkflowDriver(session: session, company: "가상전자(주)", kind: .resume)
        try driver.send(.start(input(.resume), driver.snapshot()))
        session.failing["PDF 생성"] = ("PDF 엔진 없음", [])

        try driver.send(.approve(userEdited: false))

        guard case let .failed(failure) = driver.workflow.phase else {
            Issue.record("\(driver.workflow.phase)")
            return
        }
        #expect(failure.step == .pdf)
        #expect(driver.snapshot().pdf == nil)
    }

    @Test("초안 보관은 PDF를 요청하지 않고 초안 있음으로 남는다 (DOC-024)")
    func archive() throws {
        let session = try FakeSession()
        defer { withExtendedLifetime(session) {} }
        var driver = WorkflowDriver(session: session, company: "가상전자(주)", kind: .resume)
        try driver.send(.start(input(.resume), driver.snapshot()))

        try driver.send(.archive)

        #expect(driver.workflow.phase == .archived)
        #expect(!session.received.contains { $0.kindLabel == "PDF 생성" })
        let folders = CompanyFolders.find(company: "가상전자", in: session.layout)
        #expect(TaskStateRule.fileState(.resume, folders: folders) == .waitingReview)
    }

    @Test("수정 명령이 실패하면 오류로 표시하고 잠금을 풀며 초안 내용은 그대로다 (DOC-020 · DOC-026)")
    func commandFailure() throws {
        let session = try FakeSession()
        defer { withExtendedLifetime(session) {} }
        var driver = WorkflowDriver(session: session, company: "가상전자(주)", kind: .resume)
        try driver.send(.start(input(.resume), driver.snapshot()))
        let before = try String(contentsOf: try #require(driver.snapshot().draft), encoding: .utf8)
        session.failing["수정"] = ("세션 응답 없음", [])

        try driver.send(.command("더 짧게", userEdited: false))

        #expect(driver.workflow.phase == .reviewing)
        #expect(!driver.workflow.editingLocked)
        #expect(driver.workflow.commands.map(\.status) == [.failed("세션 응답 없음")])
        #expect(try String(contentsOf: try #require(driver.snapshot().draft), encoding: .utf8) == before)
    }
}

@Suite("문서 작업 상태 기계")
struct DocumentWorkflowTests {
    private func snapshot(analysis: Bool = false, draft: Date? = nil, pdf: Date? = nil) -> DocumentSnapshot {
        DocumentSnapshot(
            analysisDone: analysis,
            draft: draft.map { _ in URL(fileURLWithPath: "/v/초안.md") }, draftModified: draft,
            pdf: pdf.map { _ in URL(fileURLWithPath: "/v/초안.pdf") }, pdfModified: pdf
        )
    }

    @Test("처리 중 같은 명령을 연타해도 요청은 1건이다 (QA-037 · DOC-027)")
    func duplicateCommand() {
        var flow = DocumentWorkflow(idPrefix: "t")
        _ = flow.handle(.start(input(.resume), snapshot(analysis: true)))
        _ = flow.handle(.files(snapshot(analysis: true, draft: Date(timeIntervalSince1970: 10))))
        let first = flow.handle(.command("짧게", userEdited: false))
        let second = flow.handle(.command("짧게", userEdited: false))
        #expect(first.count == 1)
        #expect(second.isEmpty)
        #expect(flow.commands.count == 1)
    }

    @Test("회신이 완료여도 결과 파일이 없으면 완료로 보지 않는다 (AGT-007)")
    func replyWithoutFile() throws {
        var flow = DocumentWorkflow(idPrefix: "t")
        _ = flow.handle(.start(input(.resume), snapshot(analysis: true)))
        let reply = try #require(SessionReply.parse("[채우미 회신] id=t-1 결과=완료\n파일: 초안.md"))
        _ = flow.handle(.reply(reply))
        #expect(flow.phase == .drafting(requestID: "t-1"))
    }

    @Test("PDF가 초안보다 오래됐으면 완료가 아니다 (QA-059 · DOC-013)")
    func stalePDF() {
        let old = snapshot(analysis: true, draft: Date(timeIntervalSince1970: 20), pdf: Date(timeIntervalSince1970: 10))
        #expect(!old.pdfIsCurrent)
        let current = snapshot(
            analysis: true, draft: Date(timeIntervalSince1970: 10), pdf: Date(timeIntervalSince1970: 20)
        )
        #expect(current.pdfIsCurrent)
    }

    @Test("검토 전 승인 · 다른 요청의 회신은 무시한다")
    func ignoresOutOfOrder() throws {
        var flow = DocumentWorkflow(idPrefix: "t")
        _ = flow.handle(.start(input(.resume), snapshot(analysis: true)))
        #expect(flow.handle(.approve(userEdited: false)).isEmpty)
        let other = try #require(SessionReply.parse("[채우미 회신] id=zzz 결과=실패\n사유: x"))
        _ = flow.handle(.reply(other))
        #expect(flow.phase == .drafting(requestID: "t-1"))
    }
}
