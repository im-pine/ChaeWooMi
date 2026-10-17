import Foundation
import Testing
@testable import ChaeWooMiCore

@Suite("설정 유효성 점검 (SET-006)")
struct SettingsCheckTests {
    private typealias LoadResult = Result<ApplicationStatusLoader.Loaded, ApplicationStatusLoader.LoadError>

    private func load(_ vault: borrowing TemporaryVault) -> LoadResult {
        Result { () throws(ApplicationStatusLoader.LoadError) in try ApplicationStatusLoader.load(vault: vault.root) }
    }

    @Test("볼트가 정상이면 경로 · 12.0 읽기 모두 통과하고 기록 수를 보인다")
    func vaultPassed() throws {
        let vault = try TemporaryVault()
        try vault.write("12.0 지원 현황.md", "| 회사 | 최근 제출일 |\n|---|---|\n| 가상전자 | 2026-01-01 |\n| 가상물산 | 미정 |")
        let items = SettingsCheck.vaultItems(load(vault))
        #expect(items.map(\.kind) == [.vaultPath, .statusParser])
        #expect(items[1].outcome == .passed("기록 1건, 읽지 못한 행 1개"))
        #expect(items.allSatisfy { !$0.needsAttention })
    }

    @Test("12.0을 못 찾으면 경로만 실패, 12.0 읽기는 건너뜀")
    func pathFailedSkipsParser() throws {
        let vault = try TemporaryVault()
        let items = SettingsCheck.vaultItems(load(vault))
        #expect(items.filter(\.needsAttention).map(\.kind) == [.vaultPath])
        guard case .skipped = items[1].outcome else {
            Issue.record("12.0 읽기를 건너뛰지 않음")
            return
        }
    }

    @Test("12.0은 찾았지만 표가 없으면 12.0 읽기만 실패")
    func parserFailed() throws {
        let vault = try TemporaryVault()
        try vault.write("12.0 지원 현황.md", "# 비어 있음")
        let items = SettingsCheck.vaultItems(load(vault))
        #expect(items.filter(\.needsAttention).map(\.kind) == [.statusParser])
    }

    @Test("볼트 경로를 지정하지 않았으면 경로 실패")
    func vaultNotSet() {
        #expect(SettingsCheck.vaultNotSet().filter(\.needsAttention).map(\.kind) == [.vaultPath])
    }

    @Test("세 세션이 모두 열려 있으면 통과, 하나라도 꺼져 있으면 꺼진 역할 안내로 실패")
    func sessions() {
        let all = ["job-analysis", "resume", "application"]
        #expect(!SettingsCheck.sessionItem(roster: .defaults, listed: all, error: nil).needsAttention)
        let item = SettingsCheck.sessionItem(roster: .defaults, listed: ["resume"], error: nil)
        guard case let .failed(reason) = item.outcome else {
            Issue.record("꺼진 세션이 있는데 통과함")
            return
        }
        #expect(reason.contains("claude --name job-analysis"))
        #expect(reason.contains("claude --name application"))
        #expect(!reason.contains("claude --name resume"))
    }

    @Test("세션 목록을 받지 못하면 그 오류로 실패")
    func sessionListFailed() {
        let item = SettingsCheck.sessionItem(roster: .defaults, listed: nil, error: "중계 세션이 응답하지 않습니다")
        #expect(item.outcome == .failed("중계 세션이 응답하지 않습니다"))
    }

    @Test("이전 목록이 남아 있어도 목록 확인이 실패했으면 오류로 실패한다")
    func sessionErrorWinsOverStaleList() {
        let all = ["job-analysis", "resume", "application"]
        let item = SettingsCheck.sessionItem(roster: .defaults, listed: all, error: "중계 세션이 응답하지 않습니다")
        #expect(item.outcome == .failed("중계 세션이 응답하지 않습니다"))
    }

    @Test("브라우저는 연결됨만 통과")
    func browser() {
        #expect(!SettingsCheck.browserItem(.connected(extensionVersion: "0.1.0")).needsAttention)
        #expect(SettingsCheck.browserItem(.waitingForExtension).needsAttention)
        #expect(SettingsCheck.browserItem(.hostNotRegistered).needsAttention)
    }
}
