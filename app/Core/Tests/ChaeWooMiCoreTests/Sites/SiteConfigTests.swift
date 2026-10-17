import Foundation
import Testing
@testable import ChaeWooMiCore

private let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

@Suite("지원 사이트 설정 파일 (WEB-014)")
struct SiteConfigTests {
    @Test("앱 기본 설정은 protocol/sites.default.json과 같다")
    func defaultMatchesProtocolFile() throws {
        let shared = try Data(contentsOf: repoRoot.appendingPathComponent("protocol/sites.default.json"))
        #expect(try SiteConfig.decode(shared) == SiteConfig.defaultConfig)
    }

    @Test("기본 설정은 사람인 · 잡코리아 · 원티드이고 검사에 통과한다")
    func defaultIsValid() {
        #expect(SiteConfig.defaultConfig.sites.map(\.id) == ["saramin", "jobkorea", "wanted"])
        #expect(SiteConfigValidator.problems(in: .defaultConfig).isEmpty)
    }

    @Test("기본 설정은 세 사이트 모두 구조화 데이터의 법인명을 먼저 읽는다")
    func jsonLdFirst() {
        #expect(SiteConfig.defaultConfig.sites.allSatisfy { $0.company.jsonLd })
    }

    @Test("버전 · 빈 사이트 · 겹치는 id · 도메인 형식 · 정규식 오류를 경로와 함께 알린다")
    func validation() {
        var config = SiteConfig.defaultConfig
        config.version = 2
        config.sites[1].id = "saramin"
        config.sites[2].domains = ["https://www.wanted.co.kr/"]
        config.sites[0].postingPatterns = ["(unclosed"]
        let paths = SiteConfigValidator.problems(in: config).map(\.path)
        #expect(paths.contains("version"))
        #expect(paths.contains("sites[1].id"))
        #expect(paths.contains("sites[2].domains[0]"))
        #expect(paths.contains("sites[0].postingPatterns[0]"))
    }

    @Test("회사명을 읽을 곳이 하나도 없으면 오류")
    func noCompanySource() {
        var config = SiteConfig.defaultConfig
        config.sites[0].company = SiteConfig.CompanySource(jsonLd: false, meta: [], selectors: [])
        #expect(SiteConfigValidator.problems(in: config).map(\.path) == ["sites[0].company"])
    }

    @Test("도메인은 호스트 이름만 받는다")
    func domains() {
        #expect(SiteConfigValidator.isDomain("saramin.co.kr"))
        #expect(SiteConfigValidator.isDomain("job-site.example.com"))
        #expect(!SiteConfigValidator.isDomain("localhost"))
        #expect(!SiteConfigValidator.isDomain("*.example.com"))
        #expect(!SiteConfigValidator.isDomain("example..com"))
    }
}

@Suite("설정 파일 저장소")
struct SiteConfigStoreTests {
    private let folder = FileManager.default.temporaryDirectory.appendingPathComponent("cwm-sites-\(UUID())")
    private var file: URL { folder.appendingPathComponent("sites.json") }

    @Test("파일이 없으면 기본값으로 만들고 기본값을 쓴다")
    func createsDefault() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let loaded = SiteConfigStore.load(from: file)
        #expect(loaded.config == .defaultConfig)
        #expect(loaded.problems.isEmpty)
        let written = try Data(contentsOf: file)
        #expect(try SiteConfig.decode(written) == .defaultConfig)
    }

    @Test("파일에 새 플랫폼을 더하면 코드 수정 없이 그 설정을 쓴다 (QA-063)")
    func addedPlatform() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        var config = SiteConfig.defaultConfig
        var added = config.sites[2]
        added.id = "virtualjobs"
        added.label = "가상잡스"
        added.domains = ["virtualjobs.example.com"]
        added.postingPatterns = ["^/jobs/\\\\d+"]
        config.sites.append(added)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try JSONEncoder().encode(config).write(to: file)

        let loaded = SiteConfigStore.load(from: file)
        #expect(loaded.problems.isEmpty)
        #expect(loaded.config.sites.map(\.id).contains("virtualjobs"))
    }

    @Test("파일이 깨졌거나 틀렸으면 기본값으로 동작하고 이유를 알린다")
    func invalidFileFallsBack() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("{".utf8).write(to: file)
        let broken = SiteConfigStore.load(from: file)
        #expect(broken.config == .defaultConfig)
        #expect(broken.problems.count == 1)

        var config = SiteConfig.defaultConfig
        config.sites[0].domains = []
        try JSONEncoder().encode(config).write(to: file)
        let invalid = SiteConfigStore.load(from: file)
        #expect(invalid.config == .defaultConfig)
        #expect(invalid.problems == ["sites[0].domains: 도메인이 없습니다"])
    }

    @Test("설정은 siteConfig 메시지로 확장에 보낼 수 있다")
    func message() throws {
        let data = try JSONEncoder().encode(AppToExtension.siteConfig(.defaultConfig))
        #expect(try JSONDecoder().decode(AppToExtension.self, from: data) == .siteConfig(.defaultConfig))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(object?["type"] as? String == "siteConfig")
        #expect(data.count < NativeMessageFraming.maxOutgoingBytes)
    }
}
