/// 설정 유효성 점검 (SET-006). 네 가지를 한 번에 보고, 실패한 항목만 해결 방법을 낸다.
public struct SettingsCheckItem: Equatable, Sendable {
    public enum Kind: CaseIterable, Sendable {
        case vaultPath, statusParser, sessions, browser

        public var label: String {
            switch self {
            case .vaultPath: "볼트 경로"
            case .statusParser: "12.0 읽기"
            case .sessions: "세션 연결"
            case .browser: "브라우저 연결"
            }
        }
    }

    public enum Outcome: Equatable, Sendable {
        case passed(String)
        case failed(String)
        /// 앞 단계가 실패해 확인하지 못함
        case skipped(String)
    }

    public let kind: Kind
    public let outcome: Outcome

    /// 다시 설정해야 하는 항목인가
    public var needsAttention: Bool {
        if case .failed = outcome { return true }
        return false
    }
}

public enum SettingsCheck {
    /// 볼트 경로 · 12.0 읽기 두 항목. 경로를 못 찾으면 12.0 읽기는 건너뛴다
    public static func vaultItems(
        _ result: Result<ApplicationStatusLoader.Loaded, ApplicationStatusLoader.LoadError>
    ) -> [SettingsCheckItem] {
        switch result {
        case let .success(loaded):
            let skipped = loaded.result.skippedRows
            let note = skipped > 0 ? ", 읽지 못한 행 \(skipped)개" : ""
            return [
                SettingsCheckItem(kind: .vaultPath, outcome: .passed(loaded.layout.root.path)),
                SettingsCheckItem(kind: .statusParser, outcome: .passed("기록 \(loaded.result.records.count)건\(note)"))
            ]
        case .failure(.vaultNotAFolder):
            return pathFailed("폴더가 없습니다. 볼트 폴더를 다시 선택하세요")
        case .failure(.statusFileNotFound):
            return pathFailed("볼트에서 `12.0 지원 현황.md`를 찾지 못했습니다. 볼트 루트를 선택했는지 확인하세요")
        case .failure(.unreadable):
            return parserFailed("12.0 파일을 읽을 수 없습니다. 파일 권한을 확인하세요")
        case .failure(.noStatusTable):
            return parserFailed("12.0에 회사 · 제출일 열이 있는 표가 없습니다")
        }
    }

    /// 항목별 저장 위치로 점검한다. 공고 분석 · 산출물 폴더 · 이름 문제는 볼트 경로 항목에 모아 실패로 보인다
    public static func vaultItems(paths: VaultPaths) -> [SettingsCheckItem] {
        guard !paths.statusFile.isEmpty else { return vaultNotSet() }
        let items = vaultItems(Result { () throws(ApplicationStatusLoader.LoadError) in
            try ApplicationStatusLoader.load(paths: paths)
        })
        let problems = paths.problems.filter { $0 != .statusFileMissing }
        guard !problems.isEmpty else { return items }
        let reason = problems.map(\.message).joined(separator: "\n")
        return [SettingsCheckItem(kind: .vaultPath, outcome: .failed(reason))] + items.dropFirst()
    }

    /// 볼트 경로를 아직 지정하지 않음
    public static func vaultNotSet() -> [SettingsCheckItem] {
        pathFailed("볼트 경로를 지정하세요")
    }

    /// 세 역할 세션이 모두 연결돼야 통과. 목록 확인이 실패했으면 이전 목록이 있어도 그 오류로 실패한다
    public static func sessionItem(roster: SessionRoster, listed: [String]?, error: String?) -> SettingsCheckItem {
        if let error {
            return SettingsCheckItem(kind: .sessions, outcome: .failed(error))
        }
        guard let listed else {
            return SettingsCheckItem(kind: .sessions, outcome: .failed(error ?? "세션 목록을 받지 못했습니다"))
        }
        let problems = SessionRole.allCases.compactMap { role -> String? in
            let availability = SessionAvailability.resolve(role: role, roster: roster, listed: listed)
            return availability.isConnected ? nil : availability.guidance(for: role)
        }
        guard problems.isEmpty else {
            return SettingsCheckItem(kind: .sessions, outcome: .failed(problems.joined(separator: "\n")))
        }
        return SettingsCheckItem(kind: .sessions, outcome: .passed("세 세션 연결됨"))
    }

    public static func browserItem(_ status: BrowserConnectionStatus) -> SettingsCheckItem {
        let outcome: SettingsCheckItem.Outcome = status.isProblem ? .failed(status.guidance) : .passed(status.guidance)
        return SettingsCheckItem(kind: .browser, outcome: outcome)
    }

    private static func pathFailed(_ reason: String) -> [SettingsCheckItem] {
        [
            SettingsCheckItem(kind: .vaultPath, outcome: .failed(reason)),
            SettingsCheckItem(kind: .statusParser, outcome: .skipped("볼트 경로를 먼저 고치세요"))
        ]
    }

    private static func parserFailed(_ reason: String) -> [SettingsCheckItem] {
        [
            SettingsCheckItem(kind: .vaultPath, outcome: .passed("12.0 파일 찾음")),
            SettingsCheckItem(kind: .statusParser, outcome: .failed(reason))
        ]
    }
}
