/// 문서 작업 종류 (이력서 · 자기소개서)
public enum DocumentKind: String, Sendable, CaseIterable {
    case resume
    case coverLetter
}

/// 문서 작업 하나 (회사 + 종류)
public struct DocumentJob: Hashable, Sendable {
    public let company: String
    public let kind: DocumentKind

    public init(company: String, kind: DocumentKind) {
        self.company = company
        self.kind = kind
    }
}

/// 문서 작업은 종류마다 한 번에 하나만 (AGT-009). 이력서 · 자소서는 받는 세션이 달라(RESUME · APPLICATION)
/// 함께 진행한다 (사용자 요청 2026-10-19, DOC-010 변경). 같은 종류는 회사가 달라도 하나씩.
/// 완료 · 실패 · 보관 때 풀린다. 앱 메모리에만 두고 재시작하면 볼트 파일로 상태를 다시 계산한다.
public actor DocumentJobLock {
    public enum Acquire: Equatable, Sendable {
        case granted
        /// 이미 같은 작업이 진행 중 (중복 클릭)
        case alreadyRunning
        /// 같은 종류의 다른 회사 작업이 진행 중
        case busy(DocumentJob)
    }

    /// 종류별로 잡고 있는 작업
    public private(set) var current: [DocumentKind: DocumentJob] = [:]

    public init() {}

    public func acquire(_ job: DocumentJob) -> Acquire {
        guard let held = current[job.kind] else {
            current[job.kind] = job
            return .granted
        }
        return held == job ? .alreadyRunning : .busy(held)
    }

    /// 작업이 완료 · 실패 · 보관 · 취소되면 푼다. 지금 잡고 있는 작업만 풀 수 있고 다른 작업 이름으로는 풀리지 않는다
    @discardableResult
    public func release(_ job: DocumentJob) -> Bool {
        guard current[job.kind] == job else { return false }
        current[job.kind] = nil
        return true
    }
}
