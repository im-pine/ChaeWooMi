/// 설정 화면의 브라우저 연결 상태 (SET-005). 원인마다 안내가 다르다.
public enum BrowserConnectionStatus: Equatable, Sendable {
    /// 호스트 등록 파일이 없거나 읽을 수 없음
    case hostNotRegistered
    /// 등록 파일이 다른 위치의 앱을 가리킴
    case hostPathMismatch
    /// 등록 파일의 확장 ID가 다름
    case extensionNotAllowed
    /// 등록은 됐지만 확장이 아직 연결하지 않음 (확장 미설치 · 꺼짐)
    case waitingForExtension
    case connected(extensionVersion: String)
    /// 연결됐다가 끊김 (Chrome 종료 등)
    case disconnected

    /// 등록 상태와 마지막 연결 사건으로 상태를 정한다. 등록 문제가 먼저다.
    public static func resolve(
        registration: NativeHostManifest.Registration,
        extensionVersion: String?,
        everConnected: Bool
    ) -> BrowserConnectionStatus {
        switch registration {
        case .missing, .unreadable: return .hostNotRegistered
        case .pathMismatch: return .hostPathMismatch
        case .originMismatch: return .extensionNotAllowed
        case .registered: break
        }
        if let extensionVersion { return .connected(extensionVersion: extensionVersion) }
        return everConnected ? .disconnected : .waitingForExtension
    }

    public var isProblem: Bool {
        switch self {
        case .connected: false
        default: true
        }
    }

    /// 상태 문구와 해결 방법
    public var guidance: String {
        switch self {
        case .hostNotRegistered:
            "브라우저 연결이 등록되지 않았습니다. 채우미를 /Applications에 두고 다시 실행하세요"
        case .hostPathMismatch:
            "브라우저 연결이 다른 위치의 채우미를 가리킵니다. 지금 앱을 다시 실행하면 고쳐집니다"
        case .extensionNotAllowed:
            "등록된 확장 ID가 채우미 확장과 다릅니다. 앱을 다시 실행하세요"
        case .waitingForExtension:
            "Chrome 확장이 아직 연결하지 않았습니다. 확장을 설치하고 Chrome을 다시 여세요. 연결 없이도 수동 조회는 됩니다"
        case let .connected(version):
            "Chrome 확장 연결됨 (v\(version))"
        case .disconnected:
            "Chrome 확장 연결이 끊겼습니다. Chrome이 열려 있는지 확인하세요. 수동 조회는 계속 됩니다"
        }
    }
}
