import Foundation
import Testing
@testable import ChaeWooMiCore

private func day(_ text: String) -> CalendarDay {
    CalendarDay(leadingIn: text)!
}

private func row(_ company: String, _ submitted: String, reapply: String? = nil) -> ApplicationRecord {
    ApplicationRecord(
        company: company, role: "개발", lastSubmitted: day(submitted),
        reapplyFrom: reapply.map(day), status: "결과 대기", note: ""
    )
}

@Suite("회사명 정규화 (MAT-002)")
struct CompanyNameTests {
    @Test("(주) · ㈜ · 주식회사 · (유) · 공백 · 기호 · 대소문자 차이를 같은 회사로 본다 (QA-016)")
    func legalMarks() {
        let keys = ["(주)가상전자", "가상전자(주)", "㈜ 가상전자", "주식회사 가상전자", "가상 전자 (유)", "（주）가상전자"]
            .map(CompanyName.normalize)
        #expect(Set(keys) == ["가상전자"])
        #expect(CompanyName.normalize("Virtual-Labs Inc.") == CompanyName.normalize("virtual labs inc"))
    }

    @Test("원래 표기는 표시용으로 남긴다")
    func keepsOriginal() {
        let name = CompanyName("  (주)가상전자 ")
        #expect(name.original == "(주)가상전자")
        #expect(name.key == "가상전자")
    }

    @Test("법인 표기 · 기호뿐이면 쓸 수 없는 이름")
    func unusable() {
        #expect(!CompanyName("(주)").isUsable)
        #expect(!CompanyName(" - ").isUsable)
    }
}

@Suite("회사명 기준 재지원 판별 (MAT-006 · MAT-005)")
struct CompanyMatcherTests {
    private let records = [
        row("가상전자(주)", "2026-03-01"),
        row("(주)테스트랩", "2025-01-10"),
        row("가상전자서비스", "2026-05-01")
    ]

    @Test("다른 플랫폼 표기라도 정규화가 같으면 같은 회사 기록을 찾는다")
    func matchesAcrossPlatforms() {
        let result = CompanyMatcher.match(candidates: ["주식회사 가상전자"], records: records)
        #expect(result == .matched(company: "가상전자(주)", records: [records[0]]))
    }

    @Test("이름이 겹치는 다른 법인(계열사)은 자동으로 합치지 않고 고르게 한다 (QA-017)")
    func similarNeedsChoice() {
        let result = CompanyMatcher.match(candidates: ["가상"], records: records)
        guard case let .needsChoice(choice) = result else {
            Issue.record("비슷한 이름을 자동 확정함: \(result)")
            return
        }
        #expect(Set(choice.existing) == ["가상전자(주)", "가상전자서비스"])
    }

    @Test("정확히 같은 회사가 있으면 비슷한 계열사가 있어도 그 회사로 확정한다")
    func exactWinsOverSimilar() {
        let result = CompanyMatcher.match(candidates: ["가상전자서비스"], records: records)
        #expect(result == .matched(company: "가상전자서비스", records: [records[2]]))
    }

    @Test("기록에 없는 회사는 기록 없음")
    func noRecord() {
        #expect(CompanyMatcher.match(candidates: ["가상물산"], records: records) == .noRecord(company: "가상물산"))
    }

    @Test("구조화 데이터와 화면의 회사명이 다르면 확정하지 않고 둘 다 보여 준다 (WEB-006)")
    func mismatchedSources() {
        let result = CompanyMatcher.match(candidates: ["(주)테스트랩", "테스트랩 서비스앱"], records: records)
        guard case let .needsChoice(choice) = result else {
            Issue.record("출처가 다른데 확정함: \(result)")
            return
        }
        #expect(choice.extracted == ["(주)테스트랩", "테스트랩 서비스앱"])
        #expect(choice.existing == ["(주)테스트랩"])
    }

    @Test("출처가 여럿이어도 정규화가 같으면 한 이름으로 본다")
    func sameNameFromSources() {
        let result = CompanyMatcher.match(candidates: ["(주)테스트랩", "테스트랩"], records: records)
        #expect(result == .matched(company: "(주)테스트랩", records: [records[1]]))
    }

    @Test("회사명이 비면 쓸 수 없는 이름")
    func emptyCandidates() {
        #expect(CompanyMatcher.match(candidates: ["", "(주)"], records: records) == .unusableName)
    }
}

@Suite("최근 지원일 · 재지원 주의 (MAT-007 · APP-008)")
struct ReapplyRuleTests {
    @Test("같은 회사 행이 여럿이면 가장 최근 제출일과 그 재지원 가능일을 쓴다 (QA-018)")
    func latestRow() {
        let rows = [row("가상전자", "2025-11-01"), row("가상전자", "2026-04-02"), row("가상전자", "2026-01-15")]
        let info = ReapplyRule.evaluate(rows, today: day("2026-10-17"))
        #expect(info?.lastSubmitted == day("2026-04-02"))
        #expect(info?.reapplyFrom == day("2027-04-02"))
    }

    @Test("재지원 가능일 하루 전은 재지원 주의, 당일은 라벨 없음 (QA-056)")
    func boundary() {
        let rows = [row("가상전자", "2026-10-04", reapply: "2027-10-05")]
        #expect(ReapplyRule.evaluate(rows, today: day("2027-10-04"))?.isCaution == true)
        #expect(ReapplyRule.evaluate(rows, today: day("2027-10-05"))?.isCaution == false)
    }

    @Test("재지원 가능일 칸이 비면 제출일 + 1년, 2월 29일은 다음 해 2월 28일")
    func defaultOneYear() {
        let info = ReapplyRule.evaluate([row("가상전자", "2026-03-01")], today: day("2026-10-17"))
        #expect(info?.reapplyFrom == day("2027-03-01"))
        #expect(day("2028-02-29").addingYear() == day("2029-02-28"))
    }

    @Test("표시는 YYYY.MM.DD")
    func display() {
        #expect(ReapplyInfo.display(day("2026-03-01")) == "2026.03.01")
    }

    @Test("오늘은 Asia/Seoul 기준이다 (UTC 15시 이후는 다음 날)")
    func todayInSeoul() {
        let utc = ISO8601DateFormatter().date(from: "2026-10-16T15:30:00Z")!
        #expect(CalendarDay.today(now: utc) == day("2026-10-17"))
    }
}

@Suite("재지원 판별 결과 (조회 불가 구분, MAT-013)")
struct CompanyLookupTests {
    private let today = day("2026-10-17")

    @Test("1년 이내면 재지원 주의, 지났으면 지난 기록과 함께 라벨 없음")
    func cautionAndClear() {
        let recentRows = [row("가상전자", "2026-03-01")]
        let recent = CompanyLookup.resolve(candidates: ["가상전자"], status: .success(recentRows), today: today)
        guard case .caution = recent else { Issue.record("재지원 주의가 아님: \(recent)"); return }
        let oldRows = [row("가상전자", "2025-01-01")]
        let old = CompanyLookup.resolve(candidates: ["가상전자"], status: .success(oldRows), today: today)
        guard case let .clear(_, info) = old else { Issue.record("라벨 없음이 아님: \(old)"); return }
        #expect(info?.lastSubmitted == day("2025-01-01"))
    }

    @Test("12.0을 읽지 못하면 라벨 없음이 아니라 조회 불가와 해결 방법 (QA-019)")
    func unavailable() {
        let errors: [ApplicationStatusLoader.LoadError] = [
            .vaultNotAFolder, .statusFileNotFound, .unreadable, .noStatusTable
        ]
        for error in errors {
            let result = CompanyLookup.resolve(candidates: ["가상전자"], status: .failure(error), today: today)
            guard case let .unavailable(failure) = result else { Issue.record("조회 불가가 아님: \(result)"); continue }
            #expect(!failure.fix.isEmpty)
        }
    }

    @Test("기록이 없는 회사는 라벨 없음, 회사명이 없으면 이름 입력 필요")
    func noRecordAndNoName() {
        #expect(CompanyLookup.resolve(candidates: ["가상물산"], status: .success([]), today: today)
            == .clear(company: "가상물산", info: nil))
        #expect(CompanyLookup.resolve(candidates: [], status: .success([]), today: today) == .needsName)
    }
}
