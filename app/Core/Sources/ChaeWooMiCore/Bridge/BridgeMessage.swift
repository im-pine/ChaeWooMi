import Foundation

/// 확장 → 앱 메시지. 예시는 저장소 루트 `protocol/examples/` (TS 테스트와 공용).
public enum ExtensionToApp: Equatable, Sendable {
    case hello(extensionVersion: String)
    case jobPage(site: String, url: String, company: String?)
}

/// 앱 → 확장 메시지
public enum AppToExtension: Equatable, Sendable {
    case ack(appVersion: String)
}

extension ExtensionToApp: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, extensionVersion, site, url, company
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .type) {
        case "hello":
            self = .hello(extensionVersion: try container.decode(String.self, forKey: .extensionVersion))
        case "jobPage":
            self = .jobPage(
                site: try container.decode(String.self, forKey: .site),
                url: try container.decode(String.self, forKey: .url),
                company: try container.decodeIfPresent(String.self, forKey: .company)
            )
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
        case let .jobPage(site, url, company):
            try container.encode("jobPage", forKey: .type)
            try container.encode(site, forKey: .site)
            try container.encode(url, forKey: .url)
            try container.encodeIfPresent(company, forKey: .company)
        }
    }
}

extension AppToExtension: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, appVersion
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        guard type == "ack" else {
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "모르는 type: \(type)")
        }
        self = .ack(appVersion: try container.decode(String.self, forKey: .appVersion))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .ack(version):
            try container.encode("ack", forKey: .type)
            try container.encode(version, forKey: .appVersion)
        }
    }
}
