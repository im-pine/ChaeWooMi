import Foundation

/// 시간대와 무관한 달력 날짜 (12.0의 `2026-10-04` 같은 값).
public struct CalendarDay: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init?(year: Int, month: Int, day: Int) {
        guard (1...12).contains(month), (1...Self.daysIn(year: year, month: month)).contains(day) else {
            return nil
        }
        self.year = year
        self.month = month
        self.day = day
    }

    /// 문자열 앞부분의 `YYYY-MM-DD`를 읽는다. 뒤에 붙은 말(`이후` 등)은 무시한다.
    public init?(leadingIn text: String) {
        let parts = text.trimmingCharacters(in: .whitespaces).prefix(10).split(separator: "-")
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else {
            return nil
        }
        self.init(year: year, month: month, day: day)
    }

    public var description: String {
        "\(year)-\(Self.twoDigits(month))-\(Self.twoDigits(day))"
    }

    public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    private static func daysIn(year: Int, month: Int) -> Int {
        switch month {
        case 2:
            let leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
            return leap ? 29 : 28
        case 4, 6, 9, 11:
            return 30
        default:
            return 31
        }
    }
}
