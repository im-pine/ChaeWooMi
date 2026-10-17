import Foundation

/// 공고 분석 아이콘만 눌렀을 때의 진행 (ANL-001). 문서 제작은 이 클릭을 요구하지 않는다.
/// 완료는 `공고.md`의 `## 공고 해석`으로 판정하고, 실패하면 누락 항목을 보여 보완 글과 함께 다시 요청한다 (ANL-003).
public struct AnalysisWorkflow: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case idle
        case running(requestID: String)
        case completed
        case failed(reason: String, missing: [String])
    }

    public struct Input: Equatable, Sendable {
        public let company: String
        public let platform: String
        public let url: String
        public let postingText: String?

        public init(company: String, platform: String, url: String, postingText: String?) {
            self.company = company
            self.platform = platform
            self.url = url
            self.postingText = postingText
        }
    }

    public private(set) var phase: Phase = .idle
    private var input: Input?
    private var nextID = 1
    private let idPrefix: String

    public init(idPrefix: String = "a" + UUID().uuidString.prefix(6).lowercased()) {
        self.idPrefix = idPrefix
    }

    /// 분석 시작. 이미 분석돼 있으면 요청하지 않는다 (완료 클릭은 조회만, ANL-007)
    public mutating func start(_ input: Input, analysisDone: Bool) -> SessionRequest? {
        guard !analysisDone else {
            phase = .completed
            return nil
        }
        guard !isRunning else { return nil }
        self.input = input
        return request(supplement: nil)
    }

    public mutating func filesChanged(analysisDone: Bool) {
        if isRunning, analysisDone { phase = .completed }
    }

    /// `analysisDone`은 회신을 받은 때 다시 읽은 볼트 상태. 완료 회신인데 공고 해석이 없으면 실패로 알린다
    /// `postingExists`: 회사 폴더에 `공고.md`가 있음. 완료 회신 + 공고.md면 헤딩 이름과 상관없이 완료
    public mutating func replied(_ reply: SessionReply, analysisDone: Bool, postingExists: Bool = false) {
        guard case let .running(id) = phase, reply.id == id else { return }
        if analysisDone || (reply.outcome == .completed && postingExists) {
            phase = .completed
        } else if reply.outcome == .failed {
            phase = .failed(reason: reply.reason ?? "세션이 분석하지 못함", missing: reply.missing)
        } else {
            phase = .failed(reason: "세션은 완료라고 했지만 공고.md가 없습니다", missing: [])
        }
    }

    /// 실패 뒤 보완 글을 붙여 같은 분석을 다시 요청한다
    public mutating func retry(supplement: String?) -> SessionRequest? {
        guard case .failed = phase else { return nil }
        return request(supplement: supplement)
    }

    /// 세션이 꺼져 있어 보내지 못함 → 처음으로
    public mutating func cancel() {
        if isRunning { phase = .idle }
    }

    public var requestID: String? {
        if case let .running(id) = phase { return id }
        return nil
    }

    private var isRunning: Bool { requestID != nil }

    private mutating func request(supplement: String?) -> SessionRequest? {
        guard let input else { return nil }
        let id = "\(idPrefix)-\(nextID)"
        nextID += 1
        phase = .running(requestID: id)
        return .analysis(
            company: input.company, platform: input.platform, url: input.url,
            postingText: input.postingText, supplement: supplement
        )
    }
}

/// `공고.md`의 `## 공고 해석` 절을 읽는다 (분석 결과 상세, ANL-007)
public enum PostingAnalysis {
    public static func section(in folders: CompanyFolders) -> String? {
        for folder in folders.companyFolders {
            let url = folder.appendingPathComponent("공고.md")
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if let section = section(of: text) { return section }
        }
        return nil
    }

    /// `## 공고 해석`(번호 · 덧붙임 허용) 줄부터 다음 `## ` 머리 전까지
    static func section(of text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        guard let start = lines.firstIndex(where: TaskStateRule.isAnalysisHeading) else { return nil }
        let rest = lines[(start + 1)...]
        let end = rest.firstIndex { $0.hasPrefix("## ") } ?? lines.endIndex
        return lines[(start + 1)..<end].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
