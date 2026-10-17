import ChaeWooMiCore
import Foundation
import Observation

/// 앱 로컬 설정. 볼트 파일이 아니라 UserDefaults에 둔다 (DB 없음 원칙).
@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let vaultPath = "vaultPath"
        static let sessionRoster = "sessionRoster"
    }

    private let defaults: UserDefaults

    var vaultPath: String? {
        didSet {
            defaults.set(vaultPath, forKey: Key.vaultPath)
            onVaultPathChange?()
        }
    }

    /// 볼트 경로가 바뀌면 카드가 12.0을 다시 읽는다
    @ObservationIgnored var onVaultPathChange: (@MainActor () -> Void)?

    /// 역할별 세션 이름. 처음에는 기본 이름(Brain_of_Pine/JobAnalysis · Resume · Application)
    var sessionRoster: SessionRoster {
        didSet { defaults.set(try? JSONEncoder().encode(sessionRoster), forKey: Key.sessionRoster) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        vaultPath = defaults.string(forKey: Key.vaultPath)
        sessionRoster = defaults.data(forKey: Key.sessionRoster)
            .flatMap { try? JSONDecoder().decode(SessionRoster.self, from: $0) }?
            .migratingLegacyDefaults() ?? .defaults
    }
}
