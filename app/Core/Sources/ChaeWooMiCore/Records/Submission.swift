import Foundation

/// 지원 완료 확인 폼 (HIS-002): 회사 · 직무 · 플랫폼 · 제출일을 확인 · 수정한 뒤 12.0 기록을 요청한다.
/// 제출일 기본값은 Asia/Seoul 기준 오늘 (HIS-003), 과거 날짜로 바꿀 수 있다 (HIS-004).
public struct Submission: Equatable, Sendable {
    public var company: String
    public var role: String
    public var platform: String
    /// 사용자가 입력한 그대로의 제출일 (`YYYY-MM-DD`)
    public var submitted: String

    public init(company: String, role: String, platform: String, submitted: CalendarDay) {
        self.company = company
        self.role = role
        self.platform = platform
        self.submitted = submitted.description
    }

    public enum Problem: Error, Equatable, Sendable {
        case noCompany
        case dateFormat
        case futureDate

        public var message: String {
            switch self {
            case .noCompany: "회사명을 입력하세요"
            case .dateFormat: "제출일은 YYYY-MM-DD 형식의 실제 날짜로 입력하세요"
            case .futureDate: "제출일이 오늘보다 뒤입니다"
            }
        }
    }

    /// 폼 값이 맞으면 JOB-ANALYSIS 기록 요청, 아니면 첫 문제
    public func request(today: CalendarDay) -> Result<SessionRequest, Problem> {
        let company = company.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !company.isEmpty else { return .failure(.noCompany) }
        let text = submitted.trimmingCharacters(in: .whitespaces)
        // `2026-10-17 이후`처럼 뒤에 말이 붙은 값도 거절한다
        guard text.count == 10, let day = CalendarDay(leadingIn: text) else {
            return .failure(.dateFormat)
        }
        guard day <= today else { return .failure(.futureDate) }
        return .success(.record(
            company: company,
            role: role.trimmingCharacters(in: .whitespacesAndNewlines),
            platform: platform.trimmingCharacters(in: .whitespacesAndNewlines),
            submitted: day
        ))
    }
}
