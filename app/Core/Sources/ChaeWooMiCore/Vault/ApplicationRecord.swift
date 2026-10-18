/// 12.0 지원 현황의 한 행 (회사당 1행).
public struct ApplicationRecord: Equatable, Sendable {
    /// 12.0에 적힌 원래 표기 (표시용)
    public let company: String
    public let role: String
    public let lastSubmitted: CalendarDay
    /// 표에 값이 없거나 날짜가 아니면 nil (재지원 판정 때 제출일 + 1년을 쓴다)
    public let reapplyFrom: CalendarDay?
    public let status: String
    public let note: String

    public init(
        company: String,
        role: String,
        lastSubmitted: CalendarDay,
        reapplyFrom: CalendarDay?,
        status: String,
        note: String
    ) {
        self.company = company
        self.role = role
        self.lastSubmitted = lastSubmitted
        self.reapplyFrom = reapplyFrom
        self.status = status
        self.note = note
    }
}
