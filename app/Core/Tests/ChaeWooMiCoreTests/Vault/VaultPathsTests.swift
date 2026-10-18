import Foundation
import Testing
@testable import ChaeWooMiCore

/// 실제 볼트처럼 12와 11이 다른 폴더에 있는 가상 볼트
private final class SplitVault {
    let vault: TemporaryVault
    let paths: VaultPaths

    init() throws {
        vault = try TemporaryVault()
        try vault.write("12 JobOpening/12.0 지원 현황.md", "| 회사 | 직무 | 제출일 |\n|---|---|---|\n| 가상전자(주) | 웹 | 2026-09-01 |")
        try vault.folder("12 JobOpening/12.1 Active")
        try vault.folder("11 Job/11.0 Resume/11.0.0 Output/가상물산 2025")
        try vault.folder("11 Job/11.0 Resume/11.0.0 Output/가상물산 2026")
        let root = vault.root.path
        paths = VaultPaths(
            statusFile: root + "/12 JobOpening/12.0 지원 현황.md",
            postingFolder: root + "/12 JobOpening/12.1 Active",
            outputFolder: root + "/11 Job/11.0 Resume/11.0.0 Output",
            ownerName: "테스터"
        )
    }
}

@Suite("항목별 저장 위치 · 이름 규칙 (설정, 2026-10-18)")
struct VaultPathsTests {
    @Test("기업명은 법인 표기를 빼고 쓴다", arguments: [
        ("가상정보통신(주)", "가상정보통신"), ("주식회사 가상랩", "가상랩"), ("(주)가상전자", "가상전자"),
        ("가상물산 (유)", "가상물산"), ("가상 전자", "가상 전자")
    ])
    func folderName(company: String, expected: String) {
        #expect(VaultPaths.folderName(company) == expected)
    }

    @Test("공고 분석: {공고 분석 폴더}/{기업명}/공고.md, 이미 있는 폴더면 그 폴더")
    func postingFile() throws {
        let fixture = try SplitVault()
        defer { withExtendedLifetime(fixture) {} }
        let new = try #require(fixture.paths.postingFile(company: "가상전자(주)"))
        #expect(new.path.hasSuffix("/12 JobOpening/12.1 Active/가상전자/공고.md"))
        try fixture.vault.folder("12 JobOpening/12.1 Active/가상전자")
        // 표기가 달라도(주식회사) 이미 있는 그 폴더를 쓴다
        let reused = try #require(fixture.paths.postingFile(company: "주식회사 가상전자"))
        #expect(reused.path.hasSuffix("/12 JobOpening/12.1 Active/가상전자/공고.md"))
        #expect(FileManager.default.fileExists(atPath: reused.deletingLastPathComponent().path))
    }

    @Test("초안: {산출물 폴더}/{기업명} {연도}/{이름}_이력서_{기업명}.md, 있으면 가장 최근 연도 폴더")
    func draftFile() throws {
        let fixture = try SplitVault()
        defer { withExtendedLifetime(fixture) {} }
        let fresh = try #require(fixture.paths.draftFile(.resume, company: "가상전자(주)", year: 2026))
        #expect(fresh.path.hasSuffix("/11.0.0 Output/가상전자 2026/테스터_이력서_가상전자.md"))
        let existing = try #require(fixture.paths.draftFile(.coverLetter, company: "가상물산(주)", year: 2027))
        #expect(existing.path.hasSuffix("/11.0.0 Output/가상물산 2026/테스터_자기소개서_가상물산.md"))
    }

    @Test("설정 경로로 12.0을 읽고, 산출물 폴더가 12 밖에 있어도 찾는다")
    func loadsSplitLayout() throws {
        let fixture = try SplitVault()
        defer { withExtendedLifetime(fixture) {} }
        let loaded = try ApplicationStatusLoader.load(paths: fixture.paths)
        #expect(loaded.result.records.count == 1)
        #expect(loaded.layout.outputFolder?.lastPathComponent == "11.0.0 Output")
        #expect(fixture.paths.problems.isEmpty)
    }

    @Test("예전처럼 볼트 폴더를 12 JobOpening으로 잡으면 산출물 폴더를 못 찾아 문제로 알린다 (실측 버그)")
    func legacyVaultMissesOutput() throws {
        let fixture = try SplitVault()
        defer { withExtendedLifetime(fixture) {} }
        let jobOpening = fixture.vault.root.appendingPathComponent("12 JobOpening")
        let legacy = try #require(VaultPaths.detected(vault: jobOpening))
        #expect(legacy.outputFolder.isEmpty)
        #expect(legacy.problems == [.outputFolderMissing, .ownerNameMissing])
        let fromRoot = try #require(VaultPaths.detected(vault: fixture.vault.root))
        #expect(fromRoot.problems == [.ownerNameMissing])
    }
}

@Suite("저장 경로 표준화 통합 (가상 볼트 + 가짜 세션)")
struct StandardSavePathTests {
    @Test("요청의 저장 경로에 세션이 쓰면 앱이 그 파일로 분석 완료 · 초안을 알아본다")
    func standardPaths() throws {
        let session = try FakeSession()
        defer { withExtendedLifetime(session) {} }
        session.realisticAnalysis = true
        let root = session.vault.root.path
        let paths = VaultPaths(
            statusFile: root + "/12 JobOpening/12.0 지원 현황.md", postingFolder: root + "/12 JobOpening/12.1 Active",
            outputFolder: root + "/11 Job/11.0 Resume/11.0.0 Output", ownerName: "테스터"
        )
        let input = DocumentWorkflow.Input(
            kind: .resume, company: "가상전자(주)", platform: "사람인", url: "u", postingText: "원문",
            postingPath: paths.postingFile(company: "가상전자(주)")?.path,
            draftPath: paths.draftFile(.resume, company: "가상전자(주)")?.path
        )
        var driver = WorkflowDriver(session: session, company: "가상전자(주)", kind: .resume)

        try driver.send(.start(input, driver.snapshot()))

        #expect(session.received.map(\.kindLabel) == ["공고 분석", "이력서 초안"])
        #expect(session.received.allSatisfy { $0.text(id: "x").contains("저장 경로: \(root)") })
        #expect(driver.workflow.phase == .reviewing)
        #expect(driver.opened.map(\.lastPathComponent) == ["테스터_이력서_가상전자.md"])
    }
}
