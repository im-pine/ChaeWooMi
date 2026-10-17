import Foundation

/// 회사명 정규화 (MAT-002). 법인 표기 · 공백 · 기호 · 대소문자 차이만 없앤다. 원래 표기는 표시용으로 남긴다.
public struct CompanyName: Hashable, Sendable {
    public let original: String
    /// 비교용 키. 비면 회사명으로 쓸 수 없다
    public let key: String

    public init(_ original: String) {
        self.original = original.trimmingCharacters(in: .whitespacesAndNewlines)
        key = Self.normalize(original)
    }

    /// 법인 표기(`(주)` · `㈜` · `주식회사` · `(유)` · `유한회사`)를 지우고, 글자 · 숫자만 남겨 소문자로 바꾼다
    public static func normalize(_ name: String) -> String {
        var text = name.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? name
        text = text.precomposedStringWithCanonicalMapping
        for mark in legalMarks {
            text = text.replacingOccurrences(of: mark, with: "")
        }
        let kept = text.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(kept)).lowercased()
    }

    /// 지울 법인 표기. 괄호 표기를 먼저 지워야 `주식회사`가 들어 있는 다른 말을 덜 건드린다
    static let legalMarks = ["(주)", "㈜", "( 주 )", "(유)", "㈲", "주식회사", "유한회사"]

    public var isUsable: Bool { !key.isEmpty }
}
