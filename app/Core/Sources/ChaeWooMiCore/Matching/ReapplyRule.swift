import Foundation

/// 회사의 최근 지원일 · 재지원 가능일 (MAT-007, APP-008)
public struct ReapplyInfo: Equatable, Sendable {
    /// 같은 회사 행이 여럿이면 가장 최근 제출일
    public let lastSubmitted: CalendarDay
    /// 표 값 우선, 없으면 제출일 + 1년
    public let reapplyFrom: CalendarDay
    /// 오늘이 재지원 가능일 전이면 `재지원 주의`
    public let isCaution: Bool

    /// `2026.10.04`
    public static func display(_ day: CalendarDay) -> String {
        String(format: "%04d.%02d.%02d", day.year, day.month, day.day)
    }
}

public enum ReapplyRule {
    /// 한 회사의 12.0 행들로 재지원 주의를 판정한다. 행이 없으면 nil (라벨 없음)
    public static func evaluate(_ records: [ApplicationRecord], today: CalendarDay) -> ReapplyInfo? {
        guard let latest = records.max(by: { $0.lastSubmitted < $1.lastSubmitted }) else { return nil }
        let reapplyFrom = latest.reapplyFrom ?? latest.lastSubmitted.addingYear()
        return ReapplyInfo(
            lastSubmitted: latest.lastSubmitted,
            reapplyFrom: reapplyFrom,
            isCaution: today < reapplyFrom
        )
    }
}

extension CalendarDay {
    /// 1년 뒤 같은 날. 2월 29일은 다음 해 2월 28일 (AI 결정)
    public func addingYear() -> CalendarDay {
        CalendarDay(year: year + 1, month: month, day: day)
            ?? CalendarDay(year: year + 1, month: month, day: day - 1)
            ?? self
    }

    /// 주어진 시간대(기본 Asia/Seoul)의 오늘
    public static func today(
        now: Date = Date(),
        timeZone: TimeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
    ) -> CalendarDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        return CalendarDay(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
            ?? CalendarDay(year: 1970, month: 1, day: 1)!
    }
}
