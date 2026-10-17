import Testing
@testable import ChaeWooMiCore

/// 가상 회사로 만든 12.0 지원 현황 예시
private let sample = """
# 12.0 지원 현황

## 진행 중

| 회사 | 직무 | 최근 제출일 | 재지원 가능 | 상태 | 비고 |
|---|---|---|---|---|---|
| 가상전자(주) | 프론트엔드 개발자 | 2026-10-04 | 2027-10-05 이후 | 결과 대기 | 2회: 2026-09-22, 2026-10-04 |
| **(주)테스트랩** | 웹 개발 | 2026-09-01 |  | 서류 탈락 |  |

## 종료

| 회사 | 직무 | 최근 제출일 | 재지원 가능 | 상태 | 비고 |
|---|---|---|---|---|---|
| [[주식회사 샘플소프트]] | 백엔드 | 2025-12-30 | 2026-12-31 | 불합격 |  |
"""

@Suite("12.0 지원 현황 읽기")
struct ApplicationStatusParserTests {
    @Test("진행 중 · 종료 표의 행을 모두 지원 기록으로 읽는다")
    func readsAllTables() throws {
        let result = try ApplicationStatusParser.parse(sample)
        #expect(result.records.map(\.company) == ["가상전자(주)", "(주)테스트랩", "주식회사 샘플소프트"])
        #expect(result.skippedRows == 0)
    }

    @Test("재지원 가능 칸의 날짜 뒤 말(이후)을 무시하고 날짜만 읽는다")
    func readsReapplyDateWithSuffix() throws {
        let first = try #require(try ApplicationStatusParser.parse(sample).records.first)
        #expect(first.lastSubmitted == CalendarDay(year: 2026, month: 10, day: 4))
        #expect(first.reapplyFrom == CalendarDay(year: 2027, month: 10, day: 5))
        #expect(first.role == "프론트엔드 개발자")
        #expect(first.status == "결과 대기")
    }

    @Test("재지원 가능 칸이 비면 값 없음으로 둔다")
    func emptyReapplyIsNil() throws {
        let second = try ApplicationStatusParser.parse(sample).records[1]
        #expect(second.reapplyFrom == nil)
    }

    @Test("굵게 · 위키 링크 서식을 걷어 내고 회사 표기만 남긴다")
    func stripsFormatting() throws {
        let records = try ApplicationStatusParser.parse(sample).records
        #expect(records[1].company == "(주)테스트랩")
        #expect(records[2].company == "주식회사 샘플소프트")
    }

    @Test("열 순서가 바뀌어도 머리줄 이름으로 읽는다")
    func columnsByHeaderName() throws {
        let markdown = """
        | 최근 제출일 | 회사 | 상태 |
        |---|---|---|
        | 2026-01-15 | 가상물산 | 진행 중 |
        """
        let record = try #require(try ApplicationStatusParser.parse(markdown).records.first)
        #expect(record.company == "가상물산")
        #expect(record.lastSubmitted == CalendarDay(year: 2026, month: 1, day: 15))
        #expect(record.role.isEmpty)
    }

    @Test("회사명이 비었거나 제출일이 날짜가 아닌 행은 건너뛰고 수를 센다")
    func skipsInvalidRows() throws {
        let markdown = """
        | 회사 | 최근 제출일 |
        |---|---|
        | 가상물산 | 2026-02-30 |
        |  | 2026-01-01 |
        | 가상유통 | 미정 |
        | 가상식품 | 2026-03-01 |
        """
        let result = try ApplicationStatusParser.parse(markdown)
        #expect(result.records.map(\.company) == ["가상식품"])
        #expect(result.skippedRows == 3)
    }

    @Test("실제 12.0 형식: `제출일` 열, 마감만 있는 지원 전 표는 건너뜀, 비고의 `\\|` 위키 링크 (실측 버그)")
    func submittedColumnName() throws {
        let markdown = """
        ## 지원 전 (분석 중)

        | 회사 | 직무 | 마감 | 상태 | 비고 |
        |---|---|---|---|---|
        | 가상물산 | 웹 | 2026-11-30 | 분석 중 |  |

        ## 지원 현황 (제출일 최신순, 2곳)

        | 회사 | 직무 | 제출일 | 재지원 가능 | 상태 | 비고 |
        |---|---|---|---|---|---|
        | 가상전자(주) | 웹개발자 | 2026-10-16 | 2027-10-17 이후 | 지원 완료 | 사람인 22:28 · [[12.1 Active/가상전자/공고\\|분석]] |
        | 주식회사 가상랩 | 프론트엔드 | 2026-10-15 | 2027-10-16 이후 | 이력서 열람(10-08) |  |
        """
        let result = try ApplicationStatusParser.parse(markdown)
        #expect(result.records.map(\.company) == ["가상전자(주)", "주식회사 가상랩"])
        #expect(result.skippedRows == 0)
        let first = try #require(result.records.first)
        #expect(first.lastSubmitted == CalendarDay(year: 2026, month: 10, day: 16))
        #expect(first.reapplyFrom == CalendarDay(year: 2027, month: 10, day: 17))
        #expect(first.status == "지원 완료")
        #expect(first.note.hasSuffix("분석]]") || first.note.hasSuffix("분석"))
    }

    @Test("회사 · 제출일 열이 있는 표가 없으면 오류")
    func noStatusTable() {
        #expect(throws: ApplicationStatusParser.ParseError.noStatusTable) {
            try ApplicationStatusParser.parse("| 이름 | 날짜 |\n|---|---|\n| 가 | 2026-01-01 |")
        }
    }
}

@Suite("달력 날짜")
struct CalendarDayTests {
    @Test("윤년 2월 29일은 받고 평년 2월 29일은 거부한다")
    func leapYear() {
        #expect(CalendarDay(year: 2028, month: 2, day: 29) != nil)
        #expect(CalendarDay(year: 2027, month: 2, day: 29) == nil)
    }

    @Test("YYYY-MM-DD 형식이 아니면 읽지 않는다")
    func rejectsOtherFormats() {
        #expect(CalendarDay(leadingIn: "2026/10/04") == nil)
        #expect(CalendarDay(leadingIn: "26-10-04") == nil)
        #expect(CalendarDay(leadingIn: "") == nil)
    }
}
