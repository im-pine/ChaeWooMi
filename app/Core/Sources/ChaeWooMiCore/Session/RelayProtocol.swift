import Foundation

/// 앱 → 중계 세션 요청. 중계 세션 표준 입력에 stream-json 사용자 메시지 한 줄로 들어간다.
public enum RelayRequest: Equatable, Sendable {
    /// `session`에 `text`를 글자 그대로 전달
    case send(id: String, session: String, text: String)
    /// 같은 Mac의 다른 세션 이름 목록
    case list

    /// stream-json 입력 한 줄 (끝 줄바꿈 포함)
    public func inputLine() -> String {
        let user = ["type": "user", "message": ["role": "user", "content": payload()]] as [String: Any]
        let data = (try? JSONSerialization.data(withJSONObject: user, options: [.sortedKeys])) ?? Data()
        return (String(bytes: data, encoding: .utf8) ?? "") + "\n"
    }

    private func payload() -> String {
        let object: [String: String] = switch self {
        case let .send(id, session, text): ["op": "send", "id": id, "to": session, "text": text]
        case .list: ["op": "list"]
        }
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
        return String(bytes: data, encoding: .utf8) ?? ""
    }
}

/// 중계 세션 → 앱 사건. 중계 세션이 `CHAEWOOMI {json}` 줄로 출력한다.
public enum RelayEvent: Equatable, Sendable {
    case sent(id: String)
    case notSent(id: String, reason: String)
    case agents(names: [String])
    case reply(from: String, text: String)
}

/// 중계 세션의 stream-json 출력 한 줄에서 채우미 사건을 꺼낸다.
///
/// `assistant` 메시지의 글자 블록만 본다. `result` 줄은 같은 글자를 한 번 더 담으므로 무시한다.
public enum RelayOutputParser {
    static let marker = "CHAEWOOMI "

    public static func events(fromStreamLine line: String) -> [RelayEvent] {
        guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
              object["type"] as? String == "assistant",
              let message = object["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else {
            return []
        }
        return content
            .filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
            .flatMap { $0.split(separator: "\n") }
            .compactMap { event(fromMarkedLine: String($0)) }
    }

    static func event(fromMarkedLine line: String) -> RelayEvent? {
        guard let start = line.range(of: marker) else { return nil }
        let json = line[start.upperBound...]
        guard let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
              let kind = object["event"] as? String else {
            return nil
        }
        return event(kind: kind, object)
    }

    private static func event(kind: String, _ object: [String: Any]) -> RelayEvent? {
        let id = object["id"] as? String
        switch kind {
        case "sent":
            return id.map { .sent(id: $0) }
        case "not_sent":
            return id.map { .notSent(id: $0, reason: object["reason"] as? String ?? "") }
        case "agents":
            return (object["names"] as? [String]).map { .agents(names: $0) }
        case "reply":
            guard let from = object["from"] as? String, let text = object["text"] as? String else { return nil }
            return .reply(from: from, text: text)
        default:
            return nil
        }
    }
}
