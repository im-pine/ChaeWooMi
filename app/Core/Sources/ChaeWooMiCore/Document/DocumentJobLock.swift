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

/// 이력서 · 자소서 작업은 한 번에 하나만 (AGT-009 · DOC-010).
/// 완료 · 실패 · 보관 때 풀린다. 앱 메모리에만 두고 재시작하면 볼트 파일로 상태를 다시 계산한다.
public actor DocumentJobLock {
    public enum Acquire: Equatable, Sendable {
        case granted
        /// 이미 같은 작업이 진행 중 (중복 클릭)
        case alreadyRunning
        /// 다른 문서 작업이 진행 중 → 다른 문서 버튼 비활성
        case busy(DocumentJob)
    }

    public private(set) var current: DocumentJob?

    public init() {}

    public func acquire(_ job: DocumentJob) -> Acquire {
        guard let current else {
            self.current = job
            return .granted
        }
        return current == job ? .alreadyRunning : .busy(current)
    }

    /// 작업이 완료 · 실패 · 보관 · 취소되면 푼다. 지금 잡고 있는 작업만 풀 수 있고 다른 작업 이름으로는 풀리지 않는다
    @discardableResult
    public func release(_ job: DocumentJob) -> Bool {
        guard current == job else { return false }
        current = nil
        return true
    }
}
