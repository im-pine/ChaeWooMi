/// 역할 세션의 연결 상태 (AGT-004)
public enum SessionAvailability: Equatable, Sendable {
    /// 세션 이름이 설정되지 않음 → 그 역할 사용 불가
    case notConfigured
    /// 설정한 이름의 세션이 열려 있지 않음 → 세션 열기 안내
    case off(sessionName: String)
    /// `sessionName`은 목록에 나온 그대로의 주소 (식별자가 붙어 있으면 그것까지)
    case connected(sessionName: String)

    public static func resolve(role: SessionRole, roster: SessionRoster, listed: [String]) -> SessionAvailability {
        guard let name = roster.name(for: role) else { return .notConfigured }
        guard let entry = listed.first(where: { baseName($0) == name }) else { return .off(sessionName: name) }
        return .connected(sessionName: entry)
    }

    /// 목록 이름 끝의 짧은 식별자를 뗀다: `Brain_of_Pine/Resume [9d13a3]` → `Brain_of_Pine/Resume`.
    /// Claude Code는 이름이 겹치거나 모든 세션을 확인하지 못하면 식별자를 붙인다 (2026-10-17 실측)
    public static func baseName(_ listed: String) -> String {
        let identifier = #"\s\[[0-9a-fA-F]{4,}\]$"#
        guard let range = listed.range(of: identifier, options: .regularExpression) else { return listed }
        return String(listed[..<range.lowerBound])
    }

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    /// 사유와 해결 방법. 채우미는 세션을 대신 열거나 닫지 않는다.
    public func guidance(for role: SessionRole) -> String {
        switch self {
        case .notConfigured:
            "\(role.label) 세션 이름이 설정되지 않았습니다. 설정에서 이름을 입력하세요"
        case let .off(name):
            "\(role.label) 세션이 꺼져 있습니다. 터미널에서 `claude --name \(name)`로 세션을 여세요"
        case let .connected(name):
            "\(role.label) 세션 `\(Self.baseName(name))` 연결됨"
        }
    }
}

/// 요청을 보내기 전에 받는 세션이 열려 있는지 확인한다. 꺼져 있으면 보내지 않고 안내만 한다.
public enum SessionRequestGate {
    public enum Decision: Equatable, Sendable {
        case send(sessionName: String)
        case refuse(guidance: String)
    }

    public static func decide(role: SessionRole, roster: SessionRoster, listed: [String]) -> Decision {
        let availability = SessionAvailability.resolve(role: role, roster: roster, listed: listed)
        if case let .connected(name) = availability { return .send(sessionName: name) }
        return .refuse(guidance: availability.guidance(for: role))
    }
}
