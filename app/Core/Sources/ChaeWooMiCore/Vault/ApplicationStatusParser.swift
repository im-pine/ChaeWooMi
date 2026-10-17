import Foundation
import Markdown

/// 12.0 지원 현황 Markdown에서 지원 기록 표를 읽는다.
///
/// 머리줄에 `회사` · `최근 제출일`(또는 `제출일`) 열이 있는 표만 지원 기록으로 본다 (진행 중 · 종료 표가 나뉘어 있어도 모두 읽음).
/// 열 순서는 머리줄 이름으로 찾으므로 바뀌어도 된다.
public enum ApplicationStatusParser {
    public struct Result: Equatable, Sendable {
        public let records: [ApplicationRecord]
        /// 회사명이 비었거나 최근 제출일이 날짜가 아니라 건너뛴 행 수
        public let skippedRows: Int
    }

    public enum ParseError: Error, Equatable {
        /// `회사` · `최근 제출일`(또는 `제출일`) 열이 있는 표가 없음
        case noStatusTable
    }

    public static func parse(_ markdown: String) throws(ParseError) -> Result {
        let tables = Document(parsing: markdown).children.compactMap { $0 as? Markdown.Table }
        let readers = tables.compactMap(TableReader.init)
        guard !readers.isEmpty else { throw .noStatusTable }

        var records: [ApplicationRecord] = []
        var skipped = 0
        for reader in readers {
            for row in reader.rows {
                if let record = reader.record(from: row) {
                    records.append(record)
                } else {
                    skipped += 1
                }
            }
        }
        return Result(records: records, skippedRows: skipped)
    }
}

/// 머리줄 이름으로 열 위치를 찾아 행을 지원 기록으로 바꾼다.
private struct TableReader {
    let rows: [[String]]
    private let columns: [String: Int]
    /// 제출일 열 이름. 실제 12.0은 `제출일`, 기능명세는 `최근 제출일`
    private let submittedColumn: String

    init?(_ table: Markdown.Table) {
        let header = table.head.cells.map { CellText.plain($0) }
        var columns: [String: Int] = [:]
        for (index, name) in header.enumerated() where columns[name] == nil {
            columns[name] = index
        }
        guard columns["회사"] != nil,
              let submittedColumn = ["최근 제출일", "제출일"].first(where: { columns[$0] != nil }) else { return nil }
        self.columns = columns
        self.submittedColumn = submittedColumn
        self.rows = table.body.rows.map { row in row.cells.map { CellText.plain($0) } }
    }

    func record(from row: [String]) -> ApplicationRecord? {
        let company = CellText.withoutWikiLink(value(row, "회사"))
        guard !company.isEmpty, let submitted = CalendarDay(leadingIn: value(row, submittedColumn)) else {
            return nil
        }
        return ApplicationRecord(
            company: company,
            role: value(row, "직무"),
            lastSubmitted: submitted,
            reapplyFrom: CalendarDay(leadingIn: value(row, "재지원 가능")),
            status: value(row, "상태"),
            note: value(row, "비고")
        )
    }

    private func value(_ row: [String], _ column: String) -> String {
        guard let index = columns[column], index < row.count else { return "" }
        return row[index]
    }
}

/// 표 칸의 서식(굵게 · 링크)을 걷어 낸 글자.
private enum CellText {
    static func plain(_ cell: Markdown.Table.Cell) -> String {
        cell.plainText.trimmingCharacters(in: .whitespaces)
    }

    /// Obsidian 위키 링크 `[[대상|표시]]` · `[[대상]]`을 표시 글자로 바꾼다.
    static func withoutWikiLink(_ text: String) -> String {
        guard text.hasPrefix("[["), text.hasSuffix("]]") else { return text }
        let inner = text.dropFirst(2).dropLast(2)
        let display = inner.split(separator: "|", maxSplits: 1).last ?? inner
        return String(display).trimmingCharacters(in: .whitespaces)
    }
}
