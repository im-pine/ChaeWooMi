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

    /// 회신 글을 해석한다. 머리 줄이 없으면 nil (채우미 회신이 아님)
    public static func parse(_ text: String) -> SessionReply? {
        let lines = text.components(separatedBy: .newlines)
        guard let headIndex = lines.firstIndex(where: { $0.contains(header) }),
              let fields = headFields(lines[headIndex]),
              let id = fields["id"], let result = fields["결과"] else { return nil }
        let body = lines[(headIndex + 1)...]
        let careerStart = body.firstIndex { $0.contains(careerMarker) }
        let plain = careerStart.map { body[..<$0] } ?? body
        return SessionReply(
            id: id,
            outcome: result == "완료" ? .completed : .failed,
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
