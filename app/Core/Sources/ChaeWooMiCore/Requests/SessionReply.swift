import Foundation

/// 역할 세션 → 채우미 회신 (볼트 `00.0.7 채우미 연동 지침` 4장 형식). 완료 판정은 회신이 아니라 볼트 파일로 한다.
public struct SessionReply: Equatable, Sendable {
    public enum Outcome: Equatable, Sendable {
        case completed
        case failed
    }

    public let id: String
    public let outcome: Outcome
    public let file: String?
    public let reason: String?
    /// 분석 · 작성에 없는 항목 (ANL-003 보완 안내)
    public let missing: [String]
    /// 회신 아래 붙은 `[CAREER-DB 반영 요청]` 블록 (DOC-031). 채우미는 복사 카드로만 보인다
    public let careerDBRequest: String?

    static let header = "[채우미 회신]"
    static let careerMarker = "[CAREER-DB 반영 요청]"

    /// 회신 글을 해석한다. 정해진 머리 줄(`[채우미 회신] id=… 결과=…`)이 없어도 요청 id(`id=…`)가 있으면 회신으로 본다 —
    /// 실제 역할 세션이 `[공고 분석 id=…] …` 같은 설명문으로 회신했다. 이때 `결과=실패`가 없으면 완료로 본다.
    /// id가 없거나 채우미 요청 글 자체면 nil
    public static func parse(_ text: String) -> SessionReply? {
        // 요청 글에는 회신 형식이 들어 있어, 요청을 그대로 돌려받으면 회신으로 오인할 수 있다
        guard !text.contains(requestHeader) else { return nil }
        let lines = text.components(separatedBy: .newlines)
        if let headIndex = lines.firstIndex(where: { $0.contains(header) }),
           let fields = headFields(lines[headIndex]),
           let id = fields["id"], let result = fields["결과"] {
            return reply(id: id, completed: result == "완료", body: lines[(headIndex + 1)...])
        }
        guard let id = looseID(in: text) else { return nil }
        return reply(id: id, completed: !text.contains("결과=실패"), body: lines[...])
    }

    static let requestHeader = "[채우미 요청]"

    /// 글 안 처음 나오는 `id=<요청 id>`
    private static func looseID(in text: String) -> String? {
        // 앞이 글자가 아닐 때만 (`uuid=…` 안의 `id=`를 잡지 않음)
        let pattern = #"(?<![A-Za-z0-9_])id=[A-Za-z0-9][A-Za-z0-9_-]*"#
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        return String(text[range].dropFirst(3))
    }

    private static func reply(id: String, completed: Bool, body: ArraySlice<String>) -> SessionReply {
        let careerStart = body.firstIndex { $0.contains(careerMarker) }
        let plain = careerStart.map { body[..<$0] } ?? body
        return SessionReply(
            id: id,
            outcome: completed ? .completed : .failed,
            file: value("파일", in: plain),
            reason: value("사유", in: plain),
            missing: value("누락", in: plain).map(splitList) ?? [],
            careerDBRequest: careerStart.map {
                body[$0...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        )
    }

    /// `[채우미 회신] id=q1 결과=완료` → ["id": "q1", "결과": "완료"]
    private static func headFields(_ line: String) -> [String: String]? {
        guard let range = line.range(of: header) else { return nil }
        let pairs = line[range.upperBound...].split(separator: " ").compactMap { part -> (String, String)? in
            let pair = part.split(separator: "=", maxSplits: 1)
            return pair.count == 2 ? (String(pair[0]), String(pair[1])) : nil
        }
        return Dictionary(pairs, uniquingKeysWith: { first, _ in first })
    }

    private static func value(_ key: String, in lines: ArraySlice<String>) -> String? {
        lines.lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.hasPrefix("\(key):") }
            .map { String($0.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespaces) }
    }

    private static func splitList(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == "," || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
