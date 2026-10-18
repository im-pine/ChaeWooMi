import Foundation
import Testing
@testable import ChaeWooMiCore

private let input = AnalysisWorkflow.Input(company: "가상전자(주)", platform: "원티드", url: "u", postingText: "원문")

@Suite("공고 분석 아이콘 (ANL-001 · ANL-003 · ANL-007)")
struct AnalysisWorkflowTests {
    @Test("분석 아이콘을 누르면 JOB-ANALYSIS 분석 요청 1건, 진행 중에 또 눌러도 추가 요청 없음")
    func startOnce() {
        var flow = AnalysisWorkflow(idPrefix: "a")
        let first = flow.start(input, analysisDone: false)
        #expect(first?.role == .jobAnalysis)
        #expect(flow.start(input, analysisDone: false) == nil)
        flow.filesChanged(analysisDone: true)
        #expect(flow.phase == .completed)
    }

    @Test("이미 분석된 공고는 요청하지 않고 결과만 보인다 (QA-025)")
    func alreadyDone() {
        var flow = AnalysisWorkflow(idPrefix: "a")
        #expect(flow.start(input, analysisDone: true) == nil)
        #expect(flow.phase == .completed)
    }

    @Test("실패하면 누락 항목을 보이고, 보완 글과 함께 같은 분석을 다시 요청한다 (QA-024)")
    func failureAndSupplement() throws {
        var flow = AnalysisWorkflow(idPrefix: "a")
        _ = flow.start(input, analysisDone: false)
        let reply = try #require(SessionReply.parse("[채우미 회신] id=a-1 결과=실패\n사유: 필수 자격 없음\n누락: 자격요건"))
        flow.replied(reply, analysisDone: false)
        #expect(flow.phase == .failed(reason: "필수 자격 없음", missing: ["자격요건"]))
        let retry = flow.retry(supplement: "자격요건: TypeScript 2년")
        #expect(retry?.text(id: "x").contains("사용자 보완: 자격요건: TypeScript 2년") == true)
        #expect(flow.requestID == "a-2")
    }

    @Test("공고 해석 절만 읽는다 (다음 ## 전까지)")
    func section() {
        let text = "# 공고\n## 모집 직무\n원문\n## 공고 해석\n요구사항 정리\n매칭 표\n## Resume 전달사항\n전달"
        #expect(PostingAnalysis.section(of: text) == "요구사항 정리\n매칭 표")
        #expect(PostingAnalysis.section(of: "# 공고\n원문만") == nil)
    }

    @Test("완료 회신인데 공고 해석이 없으면 실패, 있으면 완료")
    func completedReply() throws {
        var flow = AnalysisWorkflow(idPrefix: "a")
        _ = flow.start(input, analysisDone: false)
        let reply = try #require(SessionReply.parse("[채우미 회신] id=a-1 결과=완료\n파일: 공고.md"))
        var missing = flow
        missing.replied(reply, analysisDone: false)
        #expect(missing.phase == .failed(reason: "세션은 완료라고 했지만 공고.md가 없습니다", missing: []))
        flow.replied(reply, analysisDone: true)
        #expect(flow.phase == .completed)
    }
}
