import Foundation

/// Chrome Native Messaging 호스트 등록 파일. 앱이 실행될 때 Chrome 폴더에 쓴다.
public struct NativeHostManifest: Codable, Equatable, Sendable {
    public let name: String
    public let description: String
    /// 호스트 실행 파일 절대 경로 (앱 번들 안)
    public let path: String
    public let type: String
    public let allowedOrigins: [String]

    private enum CodingKeys: String, CodingKey {
        case name, description, path, type
        case allowedOrigins = "allowed_origins"
    }

    public init(hostPath: String, extensionID: String = BridgePaths.extensionID) {
        name = BridgePaths.hostName
        description = "채우미 앱과 Chrome 확장 연결"
        path = hostPath
        type = "stdio"
        allowedOrigins = ["chrome-extension://\(extensionID)/"]
    }

    /// 등록 파일 상태 (SET-005의 원인 구분에 쓴다)
    public enum Registration: Equatable, Sendable {
        case registered
        case missing
        /// 다른 위치의 앱을 가리킴 (앱을 옮긴 경우)
        case pathMismatch(registered: String)
        /// 확장 ID가 다름 → 확장 쪽에서 권한 없음(forbidden)
        case originMismatch
        case unreadable
    }

    public static func check(at url: URL, expected: NativeHostManifest) -> Registration {
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
        guard let data = try? Data(contentsOf: url),
              let current = try? JSONDecoder().decode(NativeHostManifest.self, from: data) else {
            return .unreadable
        }
        if current.path != expected.path { return .pathMismatch(registered: current.path) }
        if current.allowedOrigins != expected.allowedOrigins { return .originMismatch }
        return .registered
    }

    /// 등록 파일을 쓴다. 같은 내용이면 다시 쓰지 않는다.
    public func install(at url: URL) throws {
        if Self.check(at: url, expected: self) == .registered { return }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}
