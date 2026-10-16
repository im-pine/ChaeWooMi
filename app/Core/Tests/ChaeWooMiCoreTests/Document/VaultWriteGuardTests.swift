import Foundation
import Testing
@testable import ChaeWooMiCore

/// 가상 회사로 만든 볼트: 12.0, 회사 폴더 공고.md, 산출물 폴더 초안
private final class WriteVault {
    private let vault: TemporaryVault
    let layout: VaultLayout
    let status: URL
    let posting: URL
    let draft: URL
    let otherDraft: URL

    init() throws {
        vault = try TemporaryVault()
        status = try vault.write("12 Job/12.0 지원 현황.md", "| 회사 | 최근 제출일 |\n|---|---|\n| 가상전자 | 2026-01-01 |")
        posting = try vault.write("12 Job/12.1 Active/가상전자/공고.md", "# 공고")
        draft = try vault.write("11 Job/11.0.0 Output/가상전자 2026/테스터_이력서_가상전자.md", "# 이력서")
        otherDraft = try vault.write("11 Job/11.0.0 Output/가상전자 2026/테스터_자기소개서_가상전자.md", "# 자소서")
        layout = try VaultLocator.locate(vault: vault.root)
    }
}

@Suite("앱 쓰기 범위 제한 (SEC-005)")
struct VaultWriteGuardTests {
    @Test("모달에서 편집 중인 초안 Markdown에는 쓸 수 있다")
    func allowsEditingDraft() throws {
        let fixture = try WriteVault()
        try VaultWriteGuard.check(target: fixture.draft, editingDraft: fixture.draft, layout: fixture.layout)
        try DraftWriter(layout: fixture.layout, editingDraft: fixture.draft).save("# 고친 이력서", to: fixture.draft)
        #expect(try String(contentsOf: fixture.draft, encoding: .utf8) == "# 고친 이력서")
    }

    @Test("12.0 · 공고.md는 산출물 폴더 밖이라 쓰지 않는다")
    func refusesStatusAndPosting() throws {
        let fixture = try WriteVault()
        for target in [fixture.status, fixture.posting] {
            #expect(throws: VaultWriteGuard.Refusal.outsideOutputFolder) {
                try VaultWriteGuard.check(target: target, editingDraft: target, layout: fixture.layout)
            }
        }
    }

    @Test("산출물 폴더 안이라도 편집 중이 아닌 초안에는 쓰지 않는다")
    func refusesOtherDraft() throws {
        let fixture = try WriteVault()
        #expect(throws: VaultWriteGuard.Refusal.notEditingDraft) {
            try VaultWriteGuard.check(target: fixture.otherDraft, editingDraft: fixture.draft, layout: fixture.layout)
        }
        #expect(throws: VaultWriteGuard.Refusal.notEditingDraft) {
            try VaultWriteGuard.check(target: fixture.draft, editingDraft: nil, layout: fixture.layout)
        }
    }

    @Test("PDF는 세션이 만들므로 앱이 쓰지 않는다")
    func refusesPDF() throws {
        let fixture = try WriteVault()
        let pdf = fixture.draft.deletingPathExtension().appendingPathExtension("pdf")
        #expect(throws: VaultWriteGuard.Refusal.notMarkdown) {
            try VaultWriteGuard.check(target: pdf, editingDraft: pdf, layout: fixture.layout)
        }
    }

    @Test("`..`로 산출물 폴더를 빠져나가는 경로는 막는다")
    func refusesTraversal() throws {
        let fixture = try WriteVault()
        let escape = fixture.layout.outputFolder!.appendingPathComponent("../../12 Job/12.0 지원 현황.md")
        #expect(throws: VaultWriteGuard.Refusal.outsideOutputFolder) {
            try VaultWriteGuard.check(target: escape, editingDraft: escape, layout: fixture.layout)
        }
    }

    @Test("산출물 폴더 안의 링크가 12.0을 가리키면 막는다")
    func refusesSymlinkOut() throws {
        let fixture = try WriteVault()
        let link = fixture.layout.outputFolder!.appendingPathComponent("링크.md")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: fixture.status)
        #expect(throws: VaultWriteGuard.Refusal.outsideOutputFolder) {
            try VaultWriteGuard.check(target: link, editingDraft: link, layout: fixture.layout)
        }
    }

    @Test("거부되면 파일을 바꾸지 않는다")
    func refusedWriteLeavesFile() throws {
        let fixture = try WriteVault()
        let writer = DraftWriter(layout: fixture.layout, editingDraft: fixture.draft)
        #expect(throws: DraftWriter.WriteError.refused(.outsideOutputFolder)) {
            try writer.save("덮어쓰기", to: fixture.status)
        }
        #expect(try String(contentsOf: fixture.status, encoding: .utf8).contains("가상전자"))
    }

    @Test("산출물 폴더가 없는 볼트에서는 아무것도 쓰지 않는다")
    func noOutputFolder() throws {
        let vault = try TemporaryVault()
        try vault.write("12.0 지원 현황.md", "| 회사 | 최근 제출일 |\n|---|---|\n| 가상전자 | 2026-01-01 |")
        let draft = try vault.write("초안.md", "# 초안")
        let layout = try VaultLocator.locate(vault: vault.root)
        #expect(throws: VaultWriteGuard.Refusal.noOutputFolder) {
            try VaultWriteGuard.check(target: draft, editingDraft: draft, layout: layout)
        }
    }
}
