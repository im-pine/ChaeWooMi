import Foundation

/// 채우미가 요청을 보내는 역할 세션 3종 (AGT-001). CAREER-DB는 연결하지 않는다.
public enum SessionRole: String, CaseIterable, Codable, CodingKeyRepresentable, Sendable {
    /// 공고 분석 · 지원 기록
    case jobAnalysis
    /// 이력서
    case resume
    /// 자기소개서
    case application

    /// 사용자가 세션을 열 때 붙이는 기본 이름 (`claude --name <이름>`). 볼트 이름 + `/` + 역할 (사용자 결정 2026-10-17)
    public var defaultSessionName: String {
        switch self {
        case .jobAnalysis: "Brain_of_Pine/JobAnalysis"
        case .resume: "Brain_of_Pine/Resume"
        case .application: "Brain_of_Pine/Application"
        }
    }

    /// 2026-10-17 이전 기본 이름. 저장된 설정이 이 값 그대로면 새 기본값으로 옮긴다
    public var legacyDefaultSessionName: String {
        switch self {
        case .jobAnalysis: "job-analysis"
        case .resume: "resume"
        case .application: "application"
        }
    }

    public var label: String {
        switch self {
        case .jobAnalysis: "공고 분석 (JOB-ANALYSIS)"
        case .resume: "이력서 (RESUME)"
        case .application: "자기소개서 (APPLICATION)"
        }
    }
}

/// 역할별 세션 이름 설정 (SET-003). 역할마다 다른 세션(작업 폴더)을 쓸 수 있다.
public struct SessionRoster: Equatable, Codable, Sendable {
    public private(set) var names: [SessionRole: String]

    public init(names: [SessionRole: String] = [:]) {
        self.names = names
    }

    /// 비어 있으면 기본 이름을 쓰지 않고 "연결 안 됨"으로 둔다 (사용자가 지운 경우)
    public static let defaults = SessionRoster(
        names: Dictionary(uniqueKeysWithValues: SessionRole.allCases.map { ($0, $0.defaultSessionName) })
    )

    public func name(for role: SessionRole) -> String? {
        guard let name = names[role]?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return nil }
        return name
    }

    public mutating func set(_ name: String, for role: SessionRole) {
        names[role] = name
    }

    /// 옛 기본 이름을 그대로 쓰던 역할만 새 기본 이름으로 바꾼다. 사용자가 직접 바꾼 이름은 그대로 둔다
    public func migratingLegacyDefaults() -> SessionRoster {
        var migrated = self
        for role in SessionRole.allCases where names[role] == role.legacyDefaultSessionName {
            migrated.names[role] = role.defaultSessionName
        }
        return migrated
    }

    public enum Problem: Equatable, Sendable {
        case missing(SessionRole)
        /// 두 역할이 같은 세션을 가리킴
        case duplicated(String, [SessionRole])
    }

    /// 설정 문제 목록 (역할 순서대로)
    public var problems: [Problem] {
        let missing = SessionRole.allCases.filter { name(for: $0) == nil }.map(Problem.missing)
        let grouped = Dictionary(grouping: SessionRole.allCases.filter { name(for: $0) != nil }) { name(for: $0) ?? "" }
        let duplicated = grouped
            .filter { $0.value.count > 1 }
            .sorted { $0.key < $1.key }
            .map { Problem.duplicated($0.key, $0.value) }
        return missing + duplicated
    }
}
