/// 플로팅 카드에 무엇을 보일지 (기능명세 상태 규칙: 페이지 · 기업 · 재지원).
/// 공고 이동마다 이전 회사 결과를 지우고 새로 조회한다 (WEB-015).
public struct CardModel: Equatable, Sendable {
    public enum Content: Equatable, Sendable {
        /// 지정 외 사이트 · 공고 아닌 페이지 → 표시 없음 (런처만)
        case hidden
        /// 회사 확정 후 결과 (재지원 주의 / 라벨 없음 / 조회 불가)
        case company(name: String, lookup: CompanyLookup)
        /// 회사 선택 모달 (MAT-005)
        case choosing(CompanyMatcher.Choice)
        /// 수동 카드: 회사명 직접 입력 (WEB-007 · APP-018). 마지막 조회 결과가 있으면 함께
        case manual(lookup: CompanyLookup?)
    }

    public enum Event: Equatable, Sendable {
        case page(JobPage)
        case pageLeft
        /// Dock 우클릭 `플로팅 활성화` (APP-018)
        case manualActivated
        /// 수동 카드 · 회사명 수정에서 입력 (WEB-008)
        case nameEntered(String)
        /// 회사 선택 모달에서 기존 회사 또는 `새 회사로 추가`
        case chosen(String)
        /// 카드 닫기
        case dismissed
        /// 12.0이 바뀜 → 마지막 조회를 다시 한다 (볼트 파일 감시)
        case recheck
    }

    public private(set) var content: Content = .hidden
    /// 지금 공고 (지정 사이트). 수동 활성화면 nil
    public private(set) var page: JobPage?
    /// 수동 카드를 사용자가 직접 띄웠는가 (공고 이동으로 사라지지 않음)
    public private(set) var manualPinned = false
    /// 마지막으로 조회한 회사명 (다시 조회용)
    public private(set) var lastQuery: [String]?

    public init() {}

    /// 이벤트를 반영한다. `lookup`은 회사명 후보로 12.0을 조회하는 함수
    public mutating func handle(_ event: Event, lookup: ([String]) -> CompanyLookup) {
        switch event {
        case let .page(page):
            self.page = page
            manualPinned = false
            lastQuery = page.companies
            content = Self.content(for: lookup(page.companies))
        case .pageLeft:
            page = nil
            if !manualPinned {
                content = .hidden
                lastQuery = nil
            }
        case .manualActivated:
            manualPinned = true
            content = .manual(lookup: nil)
        case let .nameEntered(name):
            if CompanyName(name).isUsable { lastQuery = [name] }
            content = Self.enteredContent(name, lookup: lookup, manual: manualPinned || page == nil)
        case let .chosen(name):
            lastQuery = [name]
            content = Self.content(for: lookup([name]))
        case .recheck:
            recheck(lookup: lookup)
        case .dismissed:
            manualPinned = false
            content = page == nil ? .hidden : .manual(lookup: nil)
        }
    }

    private mutating func recheck(lookup: ([String]) -> CompanyLookup) {
        guard let lastQuery, content != .hidden else { return }
        if case .manual = content {
            content = .manual(lookup: lookup(lastQuery))
        } else {
            content = Self.content(for: lookup(lastQuery))
        }
    }

    /// 조회 결과 → 보일 내용. 회사명이 없으면 수동 카드
    static func content(for result: CompanyLookup) -> Content {
        switch result {
        case .needsName: .manual(lookup: nil)
        case let .needsChoice(choice): .choosing(choice)
        case let .caution(company, _), let .clear(company, _): .company(name: company, lookup: result)
        case .unavailable: .company(name: "", lookup: result)
        }
    }

    /// 빈 이름은 조회하지 않는다 (WEB-008). 수동 카드에서는 결과를 수동 카드 안에 보인다
    private static func enteredContent(_ name: String, lookup: ([String]) -> CompanyLookup, manual: Bool) -> Content {
        guard CompanyName(name).isUsable else { return .manual(lookup: nil) }
        let result = lookup([name])
        if manual, case .needsChoice = result { return content(for: result) }
        return manual ? .manual(lookup: result) : content(for: result)
    }
}
