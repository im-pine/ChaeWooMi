import Foundation

/// 지원 사이트 설정 파일 (WEB-014). 코드 수정 없이 플랫폼을 추가 · 수정한다.
/// 기본값은 저장소 루트 `protocol/sites.default.json`과 같다 (확장 테스트와 공용).
public struct SiteConfig: Codable, Equatable, Sendable {
    public var version: Int
    public var sites: [Site]

    public struct Site: Codable, Equatable, Sendable {
        public var id: String
        public var label: String
        /// 이 도메인과 하위 도메인
        public var domains: [String]
        /// `경로 + 쿼리`에 맞춰 보는 정규식. 하나라도 맞으면 공고 페이지
        public var postingPatterns: [String]
        /// 지원 완료 화면 주소: `경로 + 쿼리`에 맞춰 보는 정규식 (HIS-017)
        public var completePatterns: [String]
        /// 지원 완료 화면 문구: 보이는 글자에 들어 있으면 완료 화면 (공백은 무시)
        public var completeTexts: [String]
        public var company: CompanySource
        public var postingText: TextSource
        public var applyButtons: ApplyButtons
    }

    /// 회사명 읽는 곳. 구조화 데이터(JobPosting hiringOrganization) → 메타 → DOM 순 (WEB-006)
    public struct CompanySource: Codable, Equatable, Sendable {
        public var jsonLd: Bool
        public var meta: [MetaRule]
        public var selectors: [String]
    }

    public struct MetaRule: Codable, Equatable, Sendable {
        public var property: String
        /// 첫 번째 괄호 묶음이 회사명
        public var pattern: String
    }

    public struct TextSource: Codable, Equatable, Sendable {
        public var selectors: [String]
        /// 같은 사이트의 iframe 안 본문
        public var frames: [String]
    }

    /// 지원 버튼 (카드가 가리면 런처로 접는 데 씀)
    public struct ApplyButtons: Codable, Equatable, Sendable {
        public var selectors: [String]
        public var texts: [String]
    }

    public static func decode(_ data: Data) throws -> SiteConfig {
        try JSONDecoder().decode(SiteConfig.self, from: data)
    }

    /// 앱에 들어 있는 기본 설정
    public static let defaultConfig: SiteConfig = {
        guard let url = Bundle.module.url(forResource: "sites.default", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? decode(data) else {
            return SiteConfig(version: 1, sites: [])
        }
        return config
    }()
}
