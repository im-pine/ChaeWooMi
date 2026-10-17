/// 공고 회사의 재지원 판별 결과 (MAT-006 · APP-008 · MAT-013). 조회 실패를 "라벨 없음"과 섞지 않는다.
public enum CompanyLookup: Equatable, Sendable {
    /// 1년 이내 지원 → `재지원 주의`
    case caution(company: String, info: ReapplyInfo)
    /// 기록 없음 또는 재지원 가능일 지남 → 라벨 없음. 지난 기록이 있으면 info에 담는다
    case clear(company: String, info: ReapplyInfo?)
    /// 회사 선택 모달
    case needsChoice(CompanyMatcher.Choice)
    /// 회사명이 없음 → 수동 카드에서 입력
    case needsName
    /// 12.0을 읽지 못함 → 조회 불가 (해결 방법과 함께)
    case unavailable(LookupFailure)

    public static func resolve(
        candidates: [String],
        status: Result<[ApplicationRecord], ApplicationStatusLoader.LoadError>,
        today: CalendarDay
    ) -> CompanyLookup {
        let records: [ApplicationRecord]
        switch status {
        case let .success(rows): records = rows
        case let .failure(error): return .unavailable(LookupFailure(error))
        }
        switch CompanyMatcher.match(candidates: candidates, records: records) {
        case .unusableName:
            return .needsName
        case let .needsChoice(choice):
            return .needsChoice(choice)
        case let .noRecord(company):
            return .clear(company: company, info: nil)
        case let .matched(company, rows):
            guard let info = ReapplyRule.evaluate(rows, today: today) else {
                return .clear(company: company, info: nil)
            }
            return info.isCaution ? .caution(company: company, info: info) : .clear(company: company, info: info)
        }
    }
}

/// 조회 불가 원인과 해결 방법 (MAT-013)
public struct LookupFailure: Equatable, Sendable {
    public let reason: String
    public let fix: String

    public init(_ error: ApplicationStatusLoader.LoadError) {
        switch error {
        case .vaultNotAFolder:
            reason = "볼트 폴더가 없습니다"
            fix = "설정에서 볼트 폴더를 다시 선택하세요"
        case .statusFileNotFound:
            reason = "12.0 지원 현황을 찾지 못했습니다"
            fix = "볼트 루트를 선택했는지 설정에서 확인하세요"
        case .unreadable:
            reason = "12.0 파일을 읽을 수 없습니다"
            fix = "파일이 잠겨 있거나 권한이 없는지 확인한 뒤 다시 시도하세요"
        case .noStatusTable:
            reason = "12.0에 지원 기록 표가 없습니다"
            fix = "`회사` · `최근 제출일` 열이 있는 표인지 확인하세요"
        }
    }

    /// 볼트 경로를 아직 지정하지 않음
    public static let vaultNotSet = LookupFailure(reason: "볼트 경로가 지정되지 않았습니다", fix: "설정에서 볼트 폴더를 선택하세요")

    private init(reason: String, fix: String) {
        self.reason = reason
        self.fix = fix
    }
}
