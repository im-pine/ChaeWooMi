import Foundation

/// 설정 파일 검사. 어떤 항목이 왜 틀렸는지 경로와 함께 돌려준다 (#test/입력검증)
public enum SiteConfigValidator {
    public struct Problem: Equatable, Sendable, CustomStringConvertible {
        /// 예: `sites[1].postingPatterns[0]`
        public let path: String
        public let reason: String

        public var description: String { "\(path): \(reason)" }
    }

    public static let supportedVersion = 1

    public static func problems(in config: SiteConfig) -> [Problem] {
        var problems: [Problem] = []
        if config.version != supportedVersion {
            problems.append(Problem(path: "version", reason: "\(supportedVersion)이어야 합니다"))
        }
        if config.sites.isEmpty {
            problems.append(Problem(path: "sites", reason: "사이트가 하나 이상 있어야 합니다"))
        }
        var seenIDs = Set<String>()
        for (index, site) in config.sites.enumerated() {
            problems += siteProblems(site, at: "sites[\(index)]")
            if !site.id.isEmpty, !seenIDs.insert(site.id).inserted {
                problems.append(Problem(path: "sites[\(index)].id", reason: "`\(site.id)`가 겹칩니다"))
            }
        }
        return problems
    }

    private static func siteProblems(_ site: SiteConfig.Site, at path: String) -> [Problem] {
        var problems: [Problem] = []
        if site.id.isEmpty { problems.append(Problem(path: "\(path).id", reason: "비어 있습니다")) }
        if site.domains.isEmpty { problems.append(Problem(path: "\(path).domains", reason: "도메인이 없습니다")) }
        for (index, domain) in site.domains.enumerated() where !isDomain(domain) {
            problems.append(Problem(path: "\(path).domains[\(index)]", reason: "`\(domain)`는 도메인 형식이 아닙니다"))
        }
        if site.postingPatterns.isEmpty {
            problems.append(Problem(path: "\(path).postingPatterns", reason: "공고 주소 패턴이 없습니다"))
        }
        problems += regexProblems(site.postingPatterns, at: "\(path).postingPatterns")
        problems += regexProblems(site.completePatterns, at: "\(path).completePatterns")
        problems += regexProblems(site.company.meta.map(\.pattern), at: "\(path).company.meta.pattern")
        if !site.company.jsonLd, site.company.meta.isEmpty, site.company.selectors.isEmpty {
            problems.append(Problem(path: "\(path).company", reason: "회사명을 읽을 곳이 없습니다"))
        }
        return problems
    }

    private static func regexProblems(_ patterns: [String], at path: String) -> [Problem] {
        patterns.enumerated().compactMap { index, pattern in
            (try? NSRegularExpression(pattern: pattern)) == nil
                ? Problem(path: "\(path)[\(index)]", reason: "정규식이 아닙니다")
                : nil
        }
    }

    /// `example.co.kr` 같은 호스트 이름 (스킴 · 경로 · 와일드카드 없이)
    static func isDomain(_ text: String) -> Bool {
        let labels = text.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }
        return labels.allSatisfy { label in
            !label.isEmpty && label.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
        }
    }
}
