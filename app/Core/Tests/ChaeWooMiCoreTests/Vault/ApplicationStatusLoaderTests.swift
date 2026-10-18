import Foundation
import Testing
@testable import ChaeWooMiCore

/// 테스트마다 만드는 임시 볼트 폴더
struct TemporaryVault: ~Copyable {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("chaewoomi-vault-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    func write(_ relativePath: String, _ contents: String) throws -> URL {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func folder(_ relativePath: String) throws {
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(relativePath, isDirectory: true),
            withIntermediateDirectories: true
        )
    }
}

private let statusTable = """
| 회사 | 직무 | 최근 제출일 | 재지원 가능 | 상태 | 비고 |
|---|---|---|---|---|---|
| 가상전자(주) | 프론트엔드 | 2026-10-04 | 2027-10-05 | 결과 대기 |  |
"""

@Suite("볼트 경로 지정 · 12.0 읽기")
struct ApplicationStatusLoaderTests {
    @Test("볼트 경로에서 12.0 · 회사 폴더 · 산출물 폴더를 찾고 기록을 읽는다")
    func locatesAndLoads() throws {
        let vault = try TemporaryVault()
        let status = try vault.write("12 Job Hunting/12.0 지원 현황.md", statusTable)
        try vault.folder("12 Job Hunting/12.1 Active")
        try vault.folder("12 Job Hunting/12.2 Archive")
        try vault.folder("11 Job/11.0 Resume/11.0.0 Output")

        let loaded = try ApplicationStatusLoader.load(vault: vault.root)

        #expect(loaded.layout.statusFile.lastPathComponent == status.lastPathComponent)
        #expect(loaded.layout.activeFolder?.lastPathComponent == "12.1 Active")
        #expect(loaded.layout.archiveFolder?.lastPathComponent == "12.2 Archive")
        #expect(loaded.layout.outputFolder?.lastPathComponent == "11.0.0 Output")
        #expect(loaded.result.records.map(\.company) == ["가상전자(주)"])
    }

    @Test("회사 · 산출물 폴더가 없어도 12.0만 있으면 읽는다")
    func optionalFolders() throws {
        let vault = try TemporaryVault()
        try vault.write("12.0 지원 현황.md", statusTable)

        let loaded = try ApplicationStatusLoader.load(vault: vault.root)

        #expect(loaded.layout.activeFolder == nil)
        #expect(loaded.layout.outputFolder == nil)
        #expect(loaded.result.records.count == 1)
    }

    @Test("없는 경로면 볼트 경로 오류")
    func missingVault() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("chaewoomi-none-\(UUID())")
        #expect(throws: ApplicationStatusLoader.LoadError.vaultNotAFolder) {
            try ApplicationStatusLoader.load(vault: missing)
        }
    }

    @Test("파일을 볼트 경로로 지정하면 볼트 경로 오류")
    func fileAsVault() throws {
        let vault = try TemporaryVault()
        let file = try vault.write("note.md", "메모")
        #expect(throws: ApplicationStatusLoader.LoadError.vaultNotAFolder) {
            try ApplicationStatusLoader.load(vault: file)
        }
    }

    @Test("볼트에 12.0이 없으면 12.0 없음 오류")
    func statusFileMissing() throws {
        let vault = try TemporaryVault()
        try vault.write("메모.md", "내용")
        #expect(throws: ApplicationStatusLoader.LoadError.statusFileNotFound) {
            try ApplicationStatusLoader.load(vault: vault.root)
        }
    }

    @Test("볼트 루트에서 4단계 깊이의 12.0은 찾는다")
    func depthLimitInside() throws {
        let vault = try TemporaryVault()
        try vault.write("a/b/c/12.0 지원 현황.md", statusTable)
        #expect(try ApplicationStatusLoader.load(vault: vault.root).result.records.count == 1)
    }

    @Test("볼트 루트에서 5단계 깊이의 12.0은 찾지 않는다")
    func depthLimitOutside() throws {
        let vault = try TemporaryVault()
        try vault.write("a/b/c/d/12.0 지원 현황.md", statusTable)
        #expect(throws: ApplicationStatusLoader.LoadError.statusFileNotFound) {
            try ApplicationStatusLoader.load(vault: vault.root)
        }
    }

    @Test("12.0을 읽을 수 없으면 읽기 실패 오류")
    func unreadable() throws {
        let vault = try TemporaryVault()
        let status = try vault.write("12.0 지원 현황.md", statusTable)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: status.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: status.path) }

        #expect(throws: ApplicationStatusLoader.LoadError.unreadable) {
            try ApplicationStatusLoader.load(vault: vault.root)
        }
    }

    @Test("12.0에 지원 기록 표가 없으면 표 없음 오류")
    func noTable() throws {
        let vault = try TemporaryVault()
        try vault.write("12.0 지원 현황.md", "# 12.0 지원 현황\n\n아직 기록 없음")
        #expect(throws: ApplicationStatusLoader.LoadError.noStatusTable) {
            try ApplicationStatusLoader.load(vault: vault.root)
        }
    }
}
