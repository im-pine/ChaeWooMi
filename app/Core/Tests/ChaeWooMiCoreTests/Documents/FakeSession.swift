import Foundation
@testable import ChaeWooMiCore

/// 통합 테스트용 가짜 역할 세션. 요청을 받으면 가상 볼트에 결과 파일을 쓰고 00.0.7 형식으로 회신한다.
/// 파일 수정 시각은 가짜 시계로 1초씩 늘려 순서를 분명히 한다.
final class FakeSession {
    let vault: TemporaryVault
    let layout: VaultLayout
    let year = 2026
    /// 이 종류 요청은 실패로 회신한다 (`공고 분석` · `PDF 생성` · `수정` 등)
    var failing: [String: (reason: String, missing: [String])] = [:]
    /// 자소서 초안 회신에 붙일 CAREER-DB 반영 요청
    var careerRequest: String?
    /// 지원 기록 요청에 완료라고 회신하지만 12.0을 고치지 않음
    var skipsRecordWrite = false
    /// 실제 JOB-ANALYSIS 세션처럼: 공고.md를 번호 헤딩(`## 1. 확인된 공고 내용`)으로 쓰고 `공고 해석` 헤딩은 없으며,
    /// 회신은 00.0.7 형식이 아닌 설명문 `[공고 분석 id=…] …`
    var realisticAnalysis = false
    private(set) var received: [SessionRequest] = []
    private var clock = Date(timeIntervalSince1970: 1_900_000_000)

    init() throws {
        vault = try TemporaryVault()
        try vault.write("12 JobOpening/12.0 지원 현황.md", """
        | 회사 | 직무 | 최근 제출일 | 재지원 가능 | 상태 | 비고 |
        |---|---|---|---|---|---|
        """)
        try vault.folder("12 JobOpening/12.1 Active")
        try vault.folder("11 Job/11.0 Resume/11.0.0 Output")
        layout = try VaultLocator.locate(vault: vault.root)
    }

    /// 요청을 처리하고 회신을 돌려준다
    func handle(_ request: SessionRequest, id: String) throws -> SessionReply {
        received.append(request)
        if let failure = failing[request.kindLabel] {
            let missing = failure.missing.isEmpty ? "" : "\n누락: \(failure.missing.joined(separator: ", "))"
            return SessionReply.parse("[채우미 회신] id=\(id) 결과=실패\n사유: \(failure.reason)\(missing)")!
        }
        let path = try perform(request)
        if realisticAnalysis, case .analysis = request {
            return SessionReply.parse("[공고 분석 id=\(id)] 분석을 마쳤습니다. 요점: 자격요건이 맞습니다.\n상세: \(path)")!
        }
        var text = "[채우미 회신] id=\(id) 결과=완료\n파일: \(path)"
        if case .coverLetterDraft = request, let careerRequest { text += "\n\(careerRequest)" }
        return SessionReply.parse(text)!
    }

    func snapshot(_ kind: DocumentKind, company: String) -> DocumentSnapshot {
        DocumentSnapshot.read(kind, company: company, layout: layout)
    }

    func exists(_ relative: String) -> Bool {
        FileManager.default.fileExists(atPath: vault.root.appendingPathComponent(relative).path)
    }

    /// 사용자가 모달에서 초안을 직접 고침 (앱이 쓰는 유일한 볼트 파일)
    func userEdits(_ draft: URL, append line: String) throws {
        let text = try String(contentsOf: draft, encoding: .utf8) + "\n\(line)"
        try DraftWriter(layout: layout, editingDraft: draft).save(text, to: draft)
        try touch(draft)
    }

    private func perform(_ request: SessionRequest) throws -> String {
        switch request {
        case let .analysis(company, _, _, _, _):
            let posting = realisticAnalysis
                ? "# 공고\n\n## 1. 확인된 공고 내용\n원문\n\n## 2. 사용자 기준 적합성\n판단"
                : "# 공고\n\n## 모집 직무\n원문\n\n## 공고 해석\n분석"
            return try write("12 JobOpening/12.1 Active/\(folder(company))/공고.md", posting)
        case let .resumeDraft(company, _, _):
            return try write(outputPath(company, "이력서", "md"), "# 이력서\n요약")
        case let .coverLetterDraft(company, _, _, questions):
            let answers = questions.map { "## \($0.text)\n답변" }.joined(separator: "\n")
            return try write(outputPath(company, "자기소개서", "md"), answers)
        case let .edit(_, _, path, command, _):
            let url = URL(fileURLWithPath: path)
            let edited = try String(contentsOf: url, encoding: .utf8) + "\n(수정: \(command))"
            try edited.write(to: url, atomically: true, encoding: .utf8)
            try touch(url)
            return path
        case let .pdf(_, _, path, _):
            let pdf = URL(fileURLWithPath: path).deletingPathExtension().appendingPathExtension("pdf")
            try Data("%PDF-1.4".utf8).write(to: pdf)
            try touch(pdf)
            return pdf.path
        case let .record(company, role, platform, submitted):
            if !skipsRecordWrite { try recordRow(company, role, platform, submitted) }
            return "12 JobOpening/12.0 지원 현황.md"
        }
    }

    /// JOB-ANALYSIS 지침대로 회사당 1행: 있으면 최근 제출일 · 재지원 가능일을 갱신하고 이전 제출일은 비고로
    private func recordRow(_ company: String, _ role: String, _ platform: String, _ day: CalendarDay) throws {
        let url = layout.statusFile
        var lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
        let key = CompanyName(company).key
        let row = { (note: String) in
            "| \(company) | \(role) | \(day) | \(day.addingYear()) | 지원 완료 (\(platform)) | \(note) |"
        }
        if let index = lines.firstIndex(where: { cells($0).first.map { CompanyName($0).key } == key }) {
            let old = cells(lines[index])
            let previous = [old[5], "이전 지원 \(old[2])"].filter { !$0.isEmpty }.joined(separator: "; ")
            lines[index] = row(previous)
        } else {
            lines.append(row(""))
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        try touch(url)
    }

    private func cells(_ line: String) -> [String] {
        guard line.hasPrefix("|"), !line.hasPrefix("|---"), !line.hasPrefix("| 회사") else { return [] }
        return line.split(separator: "|", omittingEmptySubsequences: false).dropFirst().dropLast()
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// 12.0을 다시 읽음 (앱이 재조회하는 것)
    func records() throws -> [ApplicationRecord] {
        try ApplicationStatusLoader.load(vault: vault.root).result.records
    }

    private func folder(_ company: String) -> String {
        CompanyName.normalize(company)
    }

    private func outputPath(_ company: String, _ kind: String, _ ext: String) -> String {
        "11 Job/11.0 Resume/11.0.0 Output/\(company) \(year)/테스터_\(kind)_\(folder(company)).\(ext)"
    }

    private func write(_ relative: String, _ text: String) throws -> String {
        let url = try vault.write(relative, text)
        try touch(url)
        return relative
    }

    private func touch(_ url: URL) throws {
        clock += 1
        try FileManager.default.setAttributes([.modificationDate: clock], ofItemAtPath: url.path)
    }
}

/// 상태 기계의 요청 효과를 가짜 세션에 돌리고, 파일 변화 · 회신을 다시 넣는다 (앱의 CardStore가 하는 일)
struct WorkflowDriver {
    var workflow = DocumentWorkflow(idPrefix: "t")
    let session: FakeSession
    let company: String
    let kind: DocumentKind
    private(set) var opened: [URL] = []
    private(set) var careerCards: [String] = []
    private(set) var lockReleased = 0

    init(session: FakeSession, company: String, kind: DocumentKind) {
        self.session = session
        self.company = company
        self.kind = kind
    }

    mutating func send(_ event: DocumentWorkflow.Event) throws {
        var queue = workflow.handle(event)
        while !queue.isEmpty {
            let effect = queue.removeFirst()
            switch effect {
            case let .send(request, id):
                let reply = try session.handle(request, id: id)
                queue += workflow.handle(.files(session.snapshot(kind, company: company)))
                queue += workflow.handle(.reply(reply))
            case let .openReview(url): opened.append(url)
            case let .showCareerRequest(text): careerCards.append(text)
            case .releaseLock: lockReleased += 1
            }
        }
    }

    func snapshot() -> DocumentSnapshot { session.snapshot(kind, company: company) }
}
