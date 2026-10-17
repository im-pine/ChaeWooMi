import Foundation

/// 확장 → 앱 메시지. 예시는 저장소 루트 `protocol/examples/` (TS 테스트와 공용).
public enum ExtensionToApp: Equatable, Sendable {
    case hello(extensionVersion: String)
    /// 지정 사이트 공고 (회사명 후보는 구조화 데이터 → 메타 → DOM 순, 비면 추출 실패)
    case jobPage(JobPage)
    /// 공고가 아닌 페이지 · 다른 탭으로 옮김 → 이전 회사 결과를 지운다 (WEB-015)
    case pageLeft
    /// 지원 버튼이 카드 자리를 가리는가 (APP-015)
    case applyButton(covering: Bool)
}

public struct JobPage: Codable, Equatable, Sendable {
    public let site: String
    public let url: String
    public let companies: [String]
    public let title: String?
    /// 없으면 공고 원문을 찾지 못함 (WEB-011)
    public let postingText: String?

    public init(site: String, url: String, companies: [String], title: String? = nil, postingText: String? = nil) {
        self.site = site
        self.url = url
        self.companies = companies
        self.title = title
        self.postingText = postingText
    }
}

/// 앱 → 확장 메시지
public enum AppToExtension: Equatable, Sendable {
    case ack(appVersion: String)
    /// 지원 사이트 설정 (앱 소유 파일). 확장은 이 설정으로 공고 페이지를 알아본다
    case siteConfig(SiteConfig)
}

extension ExtensionToApp: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, extensionVersion, covering
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .type) {
        case "hello":
            self = .hello(extensionVersion: try container.decode(String.self, forKey: .extensionVersion))
        case "jobPage":
            self = .jobPage(try JobPage(from: decoder))
        case "pageLeft":
            self = .pageLeft
        case "applyButton":
            self = .applyButton(covering: try container.decode(Bool.self, forKey: .covering))
        case let other:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "모르는 type: \(other)")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .hello(version):
            try container.encode("hello", forKey: .type)
            try container.encode(version, forKey: .extensionVersion)
        case let .jobPage(page):
            try container.encode("jobPage", forKey: .type)
            try page.encode(to: encoder)
        case .pageLeft:
            try container.encode("pageLeft", forKey: .type)
        case let .applyButton(covering):
            try container.encode("applyButton", forKey: .type)
            try container.encode(covering, forKey: .covering)
        }
    }
}

extension AppToExtension: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, appVersion, config
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .type) {
        case "ack":
            self = .ack(appVersion: try container.decode(String.self, forKey: .appVersion))
        case "siteConfig":
            self = .siteConfig(try container.decode(SiteConfig.self, forKey: .config))
        case let other:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "모르는 type: \(other)")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .ack(version):
            try container.encode("ack", forKey: .type)
            try container.encode(version, forKey: .appVersion)
        case let .siteConfig(config):
            try container.encode("siteConfig", forKey: .type)
            try container.encode(config, forKey: .config)
        }
    }
}
