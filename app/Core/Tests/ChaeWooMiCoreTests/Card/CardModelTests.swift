import Testing
@testable import ChaeWooMiCore

private let today = CalendarDay(year: 2026, month: 10, day: 17)!
private let records = [
    ApplicationRecord(
        company: "가상전자(주)", role: "개발", lastSubmitted: CalendarDay(year: 2026, month: 3, day: 1)!,
        reapplyFrom: nil, status: "", note: ""
    ),
    ApplicationRecord(
        company: "가상전자서비스", role: "개발", lastSubmitted: CalendarDay(year: 2025, month: 1, day: 1)!,
        reapplyFrom: nil, status: "", note: ""
    )
]

private func lookup(_ names: [String]) -> CompanyLookup {
    CompanyLookup.resolve(candidates: names, status: .success(records), today: today)
}

private func page(_ companies: [String], url: String = "https://www.wanted.co.kr/wd/1") -> JobPage {
    JobPage(site: "wanted", url: url, companies: companies)
}

@Suite("플로팅 카드 상태")
struct CardModelTests {
    @Test("지정 사이트 공고에서 회사를 찾으면 그 회사의 결과를 보인다")
    func postingShowsCompany() {
        var card = CardModel()
        card.handle(.page(page(["주식회사 가상전자"])), lookup: lookup)
        guard case let .company(name, .caution) = card.content else { Issue.record("\(card.content)"); return }
        #expect(name == "가상전자(주)")
    }

    @Test("A 공고에서 B 공고로 옮기면 A의 회사 · 결과가 남지 않는다 (QA-020, WEB-015)")
    func nextPostingReplaces() {
        var card = CardModel()
        card.handle(.page(page(["가상전자"])), lookup: lookup)
        card.handle(.pageLeft, lookup: lookup)
        #expect(card.content == .hidden)
        card.handle(.page(page(["가상물산"], url: "https://www.wanted.co.kr/wd/2")), lookup: lookup)
        #expect(card.content == .company(name: "가상물산", lookup: .clear(company: "가상물산", info: nil)))
        #expect(card.page?.url == "https://www.wanted.co.kr/wd/2")
    }

    @Test("지정 사이트 공고인데 회사명을 못 읽으면 수동 카드 (WEB-007)")
    func extractionFailureShowsManual() {
        var card = CardModel()
        card.handle(.page(page([])), lookup: lookup)
        #expect(card.content == .manual(lookup: nil))
    }

    @Test("후보가 여럿이면 회사 선택, 고르면 그 회사로 조회 (MAT-005)")
    func choosing() {
        var card = CardModel()
        card.handle(.page(page(["가상"])), lookup: lookup)
        guard case .choosing = card.content else { Issue.record("\(card.content)"); return }
        card.handle(.chosen("가상전자서비스"), lookup: lookup)
        guard case let .company(name, .clear) = card.content else { Issue.record("\(card.content)"); return }
        #expect(name == "가상전자서비스")
    }

    @Test("`새 회사로 추가`로 고른 이름이 12.0에 없으면 라벨 없음")
    func chooseNewCompany() {
        var card = CardModel()
        card.handle(.page(page(["가상"])), lookup: lookup)
        card.handle(.chosen("가상우주"), lookup: lookup)
        #expect(card.content == .company(name: "가상우주", lookup: .clear(company: "가상우주", info: nil)))
    }

    @Test("회사명을 고쳐 입력하면 이전 회사 상태를 버리고 다시 조회한다 (WEB-008)")
    func editName() {
        var card = CardModel()
        card.handle(.page(page(["가상물산"])), lookup: lookup)
        card.handle(.nameEntered("가상전자(주)"), lookup: lookup)
        guard case let .company(name, .caution) = card.content else { Issue.record("\(card.content)"); return }
        #expect(name == "가상전자(주)")
    }

    @Test("빈 이름은 조회하지 않는다 (WEB-008)")
    func emptyNameNotLooked() {
        var card = CardModel()
        card.handle(.manualActivated, lookup: lookup)
        var calls = 0
        card.handle(.nameEntered("  "), lookup: { calls += 1; return lookup($0) })
        #expect(calls == 0)
        #expect(card.content == .manual(lookup: nil))
    }

    @Test("Dock에서 띄운 수동 카드는 입력 결과를 카드 안에 보이고, 페이지 이동으로 사라지지 않는다 (APP-018)")
    func manualPinned() {
        var card = CardModel()
        card.handle(.manualActivated, lookup: lookup)
        card.handle(.nameEntered("가상전자"), lookup: lookup)
        guard case .manual(.caution?) = card.content else { Issue.record("\(card.content)"); return }
        card.handle(.pageLeft, lookup: lookup)
        guard case .manual = card.content else { Issue.record("수동 카드가 사라짐"); return }
        card.handle(.dismissed, lookup: lookup)
        #expect(card.content == .hidden)
    }

    @Test("12.0을 읽지 못하면 조회 불가 결과를 보인다 (라벨 없음처럼 보이지 않음)")
    func unavailable() {
        var card = CardModel()
        card.handle(.page(page(["가상전자"])), lookup: { names in
            CompanyLookup.resolve(candidates: names, status: .failure(.unreadable), today: today)
        })
        guard case .company(_, .unavailable) = card.content else { Issue.record("\(card.content)"); return }
    }

    @Test("12.0이 바뀌면 마지막 조회를 다시 해 결과를 갱신한다 (볼트 파일 감시)")
    func recheckAfterVaultChange() {
        var card = CardModel()
        var rows: [ApplicationRecord] = []
        let changing: ([String]) -> CompanyLookup = {
            CompanyLookup.resolve(candidates: $0, status: .success(rows), today: today)
        }
        card.handle(.page(page(["가상전자(주)"])), lookup: changing)
        #expect(card.content == .company(name: "가상전자(주)", lookup: .clear(company: "가상전자(주)", info: nil)))
        rows = records
        card.handle(.recheck, lookup: changing)
        guard case .company(_, .caution) = card.content else { Issue.record("\(card.content)"); return }
    }

    @Test("표시 중인 카드가 없으면 다시 조회하지 않는다")
    func recheckWhenHidden() {
        var card = CardModel()
        var calls = 0
        card.handle(.recheck, lookup: { calls += 1; return lookup($0) })
        #expect(calls == 0)
    }

    @Test("회사 선택을 취소한 뒤 볼트가 바뀌어도 입력하지 않은 이전 후보로 조회하지 않는다")
    func dismissClearsQuery() {
        var card = CardModel()
        card.handle(.page(page(["가상"])), lookup: lookup)
        card.handle(.dismissed, lookup: lookup)
        #expect(card.content == .manual(lookup: nil))
        var calls = 0
        card.handle(.recheck, lookup: { calls += 1; return lookup($0) })
        #expect(calls == 0)
        #expect(card.content == .manual(lookup: nil))
    }

    @Test("Dock에서 수동 카드를 띄우면 이전 공고 후보로 다시 조회하지 않는다")
    func manualActivationClearsQuery() {
        var card = CardModel()
        card.handle(.page(page(["가상전자"])), lookup: lookup)
        card.handle(.manualActivated, lookup: lookup)
        card.handle(.recheck, lookup: lookup)
        #expect(card.content == .manual(lookup: nil))
    }
}
