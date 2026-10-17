import Foundation
import Testing
@testable import ChaeWooMiCore

/// 가상 회사 볼트: 진행 중 · 종료 회사 폴더와 산출물 폴더
private final class CardVault {
    let vault: TemporaryVault
    let layout: VaultLayout

    init() throws {
        vault = try TemporaryVault()
        try vault.write("12 Job/12.0 지원 현황.md", "| 회사 | 최근 제출일 |\n|---|---|\n| 가상전자(주) | 2026-01-01 |")
        try vault.write("12 Job/12.1 Active/가상전자/공고.md", "# 공고\n\n## 공고 해석\n\n분석 내용")
        try vault.write("12 Job/12.1 Active/가상물산/공고.md", "# 공고\n\n원문만 있음")
        try vault.folder("12 Job/12.2 Archive/2025/가상물산")
        try vault.folder("11 Job/11.0.0 Output/가상전자 2026")
        layout = try VaultLocator.locate(vault: vault.root)
    }

    func write(_ path: String, modified: Date) throws {
        let url = try vault.write(path, "내용")
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
    }
}

@Suite("회사 폴더 매칭 (MAT-016)")
struct CompanyFoldersTests {
    @Test("법인 표기가 있는 회사명을 정규화해 회사 폴더 · 연도 붙은 산출물 폴더와 연결한다 (QA-058)")
    func matchesFolders() throws {
        let fixture = try CardVault()

        // 테스트 끝까지 임시 볼트를 지우지 않도록 붙잡아 둔다

        defer { withExtendedLifetime(fixture) {} }
        let folders = CompanyFolders.find(company: "가상전자(주)", in: fixture.layout)
        #expect(folders.companyFolders.map(\.lastPathComponent) == ["가상전자"])
        #expect(folders.outputFolders.map(\.lastPathComponent) == ["가상전자 2026"])
        #expect(folders.documents.map(\.lastPathComponent) == ["공고.md"])
        #expect(!folders.needsConfirmation)
    }

    @Test("진행 중 · 종료 폴더에 같은 회사가 둘 이상이면 사용자 확인")
    func multipleNeedsConfirmation() throws {
        let fixture = try CardVault()

        // 테스트 끝까지 임시 볼트를 지우지 않도록 붙잡아 둔다

        defer { withExtendedLifetime(fixture) {} }
        let folders = CompanyFolders.find(company: "주식회사 가상물산", in: fixture.layout)
        #expect(folders.companyFolders.count == 2)
        #expect(folders.needsConfirmation)
    }

    @Test("폴더 이름 끝의 연도만 뗀다")
    func withoutYear() {
        #expect(CompanyFolders.withoutYear("가상전자 2026") == "가상전자")
        #expect(CompanyFolders.withoutYear("가상2026") == "가상2026")
    }
}

@Suite("아이콘 3종 독립 상태 (APP-012) · 클릭 분기 (APP-017)")
struct TaskStateTests {
    @Test("분석은 공고.md에 `## 공고 해석`이 있으면 완료, 없으면 시작 전")
    func analysis() throws {
        let fixture = try CardVault()

        // 테스트 끝까지 임시 볼트를 지우지 않도록 붙잡아 둔다

        defer { withExtendedLifetime(fixture) {} }
        let done = CompanyFolders.find(company: "가상전자", in: fixture.layout)
        let notYet = CompanyFolders.find(company: "가상물산", in: fixture.layout)
        #expect(TaskStateRule.fileState(.analysis, folders: done) == .completed)
        #expect(TaskStateRule.fileState(.analysis, folders: notYet) == .ready)
    }

    @Test("문서는 md만 있거나 md가 더 최신이면 초안 있음, PDF가 더 최신이면 완료, 없으면 시작 전")
    func documents() throws {
        let fixture = try CardVault()

        // 테스트 끝까지 임시 볼트를 지우지 않도록 붙잡아 둔다

        defer { withExtendedLifetime(fixture) {} }
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        try fixture.write("11 Job/11.0.0 Output/가상전자 2026/테스터_이력서_가상전자.md", modified: base)
        try fixture.write("11 Job/11.0.0 Output/가상전자 2026/테스터_이력서_가상전자.pdf", modified: base + 60)
        try fixture.write("11 Job/11.0.0 Output/가상전자 2026/테스터_자기소개서_가상전자.md", modified: base)
        let folders = CompanyFolders.find(company: "가상전자", in: fixture.layout)
        #expect(TaskStateRule.fileState(.resume, folders: folders) == .completed)
        #expect(TaskStateRule.fileState(.coverLetter, folders: folders) == .waitingReview)

        try fixture.write("11 Job/11.0.0 Output/가상전자 2026/테스터_이력서_가상전자.md", modified: base + 120)
        #expect(TaskStateRule.fileState(.resume, folders: folders) == .waitingReview)
    }

    @Test("세 아이콘은 서로 독립이다: 하나가 완료여도 다른 것은 시작 전")
    func independent() throws {
        let fixture = try CardVault()

        // 테스트 끝까지 임시 볼트를 지우지 않도록 붙잡아 둔다

        defer { withExtendedLifetime(fixture) {} }
        let folders = CompanyFolders.find(company: "가상전자", in: fixture.layout)
        let states = TaskKind.allCases.map { TaskStateRule.fileState($0, folders: folders) }
        #expect(states == [.completed, .ready, .ready])
    }

    @Test("사용 불가 > 진행 중 > 실패 > 파일 상태 순으로 정한다")
    func overlay() {
        let empty = CompanyFolders(companyFolders: [], outputFolders: [])
        func state(
            running: Set<TaskKind> = [],
            failures: [TaskKind: String] = [:],
            reason: String? = nil
        ) -> TaskState {
            TaskStateRule.state(
                .resume, folders: empty, running: running, failures: failures, unavailableReason: reason
            )
        }
        #expect(state(running: [.resume], reason: "회사 미확정") == .unavailable("회사 미확정"))
        #expect(state(running: [.resume], failures: [.resume: "x"]) == .running)
        #expect(state(failures: [.resume: "세션 응답 없음"]) == .failed("세션 응답 없음"))
        #expect(state() == .ready)
    }

    @Test("완료 · 진행 중 아이콘을 다시 눌러도 새 작업을 만들지 않는다 (QA-006 · QA-007)")
    func clickRouting() {
        #expect(TaskAction.onClick(.completed) == .showResult)
        #expect(TaskAction.onClick(.running) == .showProgress)
        #expect(TaskAction.onClick(.waitingReview) == .openReview)
        #expect(TaskAction.onClick(.failed("x")) == .showFailure("x"))
        #expect(TaskAction.onClick(.unavailable("세션 꺼짐")) == .explain("세션 꺼짐"))
        let states: [TaskState] = [.running, .waitingReview, .completed, .failed("x"), .unavailable("y")]
        #expect(states.filter { TaskAction.onClick($0).startsWork }.isEmpty)
        #expect(TaskAction.onClick(.ready).startsWork)
    }

    @Test("다음 해에 다시 지원하면 지난 연도 산출물로 아이콘을 정하지 않는다")
    func latestYearOnly() throws {
        let fixture = try CardVault()
        // 테스트 끝까지 임시 볼트를 지우지 않도록 붙잡아 둔다
        defer { withExtendedLifetime(fixture) {} }
        try fixture.write("11 Job/11.0.0 Output/가상전자 2025/테스터_이력서_가상전자.pdf", modified: Date())
        let folders = CompanyFolders.find(company: "가상전자", in: fixture.layout)
        #expect(folders.currentOutputFolders.map(\.lastPathComponent) == ["가상전자 2026"])
        #expect(TaskStateRule.fileState(.resume, folders: folders) == .ready)
    }
}

@Suite("공고 해석 헤딩")
struct AnalysisHeadingTests {
    @Test("번호 · 덧붙임이 있어도 분석 헤딩 (실제 공고.md 형식)", arguments: [
        ("## 공고 해석", true),
        ("## 2. 공고 해석", true),
        ("## 2. 공고 해석 (스냅샷 기준)", true),
        ("## 2.1 공고 해석", true),
        ("### 공고 해석", false),
        ("## 1. 확인된 공고 내용", false),
        ("공고 해석", false)
    ])
    func heading(line: String, expected: Bool) {
        #expect(TaskStateRule.isAnalysisHeading(line) == expected)
    }

    @Test("번호 헤딩 아래 분석 내용을 상세에 보인다")
    func section() {
        let text = "## 1. 확인된 공고 내용\n원문\n## 2. 공고 해석\n분석 본문\n## 3. 매칭\n표"
        #expect(PostingAnalysis.section(of: text) == "분석 본문")
    }
}
