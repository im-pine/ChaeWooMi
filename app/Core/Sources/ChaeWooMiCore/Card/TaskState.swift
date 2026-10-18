import Foundation

/// 카드의 작업 아이콘 3종. 서로 독립 상태다 (APP-012)
public enum TaskKind: String, CaseIterable, Sendable {
    case analysis, resume, coverLetter

    public var label: String {
        switch self {
        case .analysis: "공고 분석"
        case .resume: "이력서"
        case .coverLetter: "자기소개서"
        }
    }

    /// 산출물 파일 이름에 들어가는 말 (`<이름>_이력서_<회사>.md`)
    var outputMarker: String? {
        switch self {
        case .analysis: nil
        case .resume: "_이력서_"
        case .coverLetter: "_자기소개서_"
        }
    }
}

public enum TaskState: Equatable, Sendable {
    case ready
    case running
    /// (문서) 초안 md는 있고 PDF가 없거나 md가 더 최신
    case waitingReview
    case completed
    case failed(String)
    case unavailable(String)

    public var label: String {
        switch self {
        case .ready: "시작 전"
        case .running: "진행 중"
        case .waitingReview: "초안 있음"
        case .completed: "완료"
        case .failed: "실패"
        case .unavailable: "사용 불가"
        }
    }
}

/// 볼트 파일만 보고 아이콘 상태를 정한다 (DB 없음). 진행 중 · 실패는 앱 메모리에서 덮어쓴다.
public enum TaskStateRule {
    public static let analysisHeading = "## 공고 해석"

    /// `## 공고 해석`, `## 2. 공고 해석`, `## 2. 공고 해석 (스냅샷 기준)`처럼 번호 · 덧붙임이 있어도 분석 헤딩으로 본다
    /// (실제 JOB-ANALYSIS 세션이 번호를 붙여 씀)
    public static func isAnalysisHeading(_ line: String) -> Bool {
        let text = line.trimmingCharacters(in: .whitespaces)
        guard text.hasPrefix("## ") else { return false }
        let number = #"^\d+(\.\d+)*\.?\s*"#
        let title = text.dropFirst(3).replacingOccurrences(of: number, with: "", options: .regularExpression)
        return title.hasPrefix("공고 해석")
    }

    /// 회사 폴더에 `공고.md`가 있음 (세션이 분석 완료를 회신했을 때, 헤딩 이름에 기대지 않고 다음 단계로 간다)
    public static func postingExists(_ folders: CompanyFolders) -> Bool {
        folders.companyFolders.contains {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("공고.md").path)
        }
    }

    public static func fileState(_ kind: TaskKind, folders: CompanyFolders) -> TaskState {
        switch kind {
        case .analysis:
            return analysisDone(folders) ? .completed : .ready
        case .resume, .coverLetter:
            return documentState(kind, folders: folders)
        }
    }

    /// 앱 메모리의 진행 중 · 실패와 사용 불가 사유를 파일 상태 위에 얹는다
    public static func state(
        _ kind: TaskKind,
        folders: CompanyFolders?,
        running: Set<TaskKind>,
        failures: [TaskKind: String],
        unavailableReason: String?
    ) -> TaskState {
        if let unavailableReason { return .unavailable(unavailableReason) }
        if running.contains(kind) { return .running }
        if let failure = failures[kind] { return .failed(failure) }
        guard let folders else { return .ready }
        return fileState(kind, folders: folders)
    }

    /// 공고 분석은 `{공고 분석 폴더}/{기업명}/공고.md`에 저장된다 → 파일이 있으면 분석 완료 (사용자 결정, 2026-10-18).
    /// 실제 세션은 헤딩을 `## 2. 공고 해석` · `## 2. 매칭` 등으로 제각각 써서 헤딩으로는 판정하지 않는다
    private static func analysisDone(_ folders: CompanyFolders) -> Bool {
        postingExists(folders)
    }

    private static func documentState(_ kind: TaskKind, folders: CompanyFolders) -> TaskState {
        guard let marker = kind.outputMarker else { return .ready }
        let files = folders.currentOutputFolders.flatMap { folder in
            (try? FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.contentModificationDateKey]
            )) ?? []
        }.filter { $0.lastPathComponent.contains(marker) }
        let markdown = newest(files.filter { $0.pathExtension.lowercased() == "md" })
        let pdf = newest(files.filter { $0.pathExtension.lowercased() == "pdf" })
        switch (markdown, pdf) {
        case (nil, nil): return .ready
        case (_?, nil): return .waitingReview
        case (nil, _?): return .completed
        case let (draft?, final?): return draft > final ? .waitingReview : .completed
        }
    }

    /// 가장 최근 수정 시각
    private static func newest(_ files: [URL]) -> Date? {
        files
            .compactMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
            .max()
    }
}

/// 아이콘 클릭 결과 (APP-017). 완료 · 진행 중 아이콘을 다시 눌러도 새 작업을 만들지 않는다
public enum TaskAction: Equatable, Sendable {
    case start
    case showProgress
    case openReview
    case showResult
    case showFailure(String)
    case explain(String)

    public static func onClick(_ state: TaskState) -> TaskAction {
        switch state {
        case .ready: .start
        case .running: .showProgress
        case .waitingReview: .openReview
        case .completed: .showResult
        case let .failed(reason): .showFailure(reason)
        case let .unavailable(reason): .explain(reason)
        }
    }

    /// 세션에 새 요청을 보내는 클릭인가
    public var startsWork: Bool { self == .start }
}
