/// 회사명만으로 12.0 기록을 찾는다 (MAT-006). 공고 ID · URL은 쓰지 않는다.
public enum CompanyMatcher {
    public enum Result: Equatable, Sendable {
        /// 한 회사로 확정. 같은 회사의 행이 여럿이면 모두 담는다
        case matched(company: String, records: [ApplicationRecord])
        /// 기록 없음
        case noRecord(company: String)
        /// 확정할 수 없음 → 회사 선택 모달 (MAT-005). 임의로 1순위를 정하지 않는다
        case needsChoice(Choice)
        /// 회사명이 비었거나 법인 표기 · 기호뿐
        case unusableName
    }

    public struct Choice: Equatable, Sendable {
        /// 공고에서 읽은 이름들 (출처가 둘 이상이고 서로 다르면 모두)
        public let extracted: [String]
        /// 12.0에서 고를 수 있는 회사 (원래 표기, 중복 없음)
        public let existing: [String]
    }

    /// `candidates`는 공고에서 읽은 회사명 (구조화 데이터 → 메타 → DOM 순)
    public static func match(candidates: [String], records: [ApplicationRecord]) -> Result {
        let names = distinctNames(candidates)
        guard !names.isEmpty else { return .unusableName }
        let groups = Dictionary(grouping: records) { CompanyName($0.company).key }

        if names.count == 1, let name = names.first {
            return single(name, groups: groups)
        }
        // 출처끼리 이름이 다르면 확정하지 않는다 (WEB-006 검증 필요)
        let existing = names.flatMap { exactAndSimilar($0, groups: groups) }
        return .needsChoice(Choice(extracted: names.map(\.original), existing: unique(existing)))
    }

    private static func single(_ name: CompanyName, groups: [String: [ApplicationRecord]]) -> Result {
        if let rows = groups[name.key] {
            return .matched(company: rows[0].company, records: rows)
        }
        let similar = exactAndSimilar(name, groups: groups)
        guard similar.isEmpty else {
            // 계열사 · 자회사처럼 이름이 겹치는 회사는 자동으로 합치지 않는다
            return .needsChoice(Choice(extracted: [name.original], existing: similar))
        }
        return .noRecord(company: name.original)
    }

    /// 키가 같거나, 한쪽 키가 다른 쪽을 포함하는 회사 (두 글자 이상)
    private static func exactAndSimilar(_ name: CompanyName, groups: [String: [ApplicationRecord]]) -> [String] {
        groups
            .filter { key, _ in key == name.key || isSimilar(key, name.key) }
            .sorted { $0.key < $1.key }
            .map { $0.value[0].company }
    }

    static func isSimilar(_ lhs: String, _ rhs: String) -> Bool {
        guard lhs.count >= 2, rhs.count >= 2, lhs != rhs else { return false }
        return lhs.contains(rhs) || rhs.contains(lhs)
    }

    private static func distinctNames(_ candidates: [String]) -> [CompanyName] {
        var seen = Set<String>()
        return candidates.map(CompanyName.init).filter { $0.isUsable && seen.insert($0.key).inserted }
    }

    private static func unique(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }
}
