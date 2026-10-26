import ChaeWooMiCore
import Foundation
import Observation

/// 앱 로컬 설정. 볼트 파일이 아니라 UserDefaults에 둔다 (DB 없음 원칙).
@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let vaultPath = "vaultPath"
        static let vaultPaths = "vaultPaths"
        static let sessionRoster = "sessionRoster"
    }

    private let defaults: UserDefaults

    /// 항목별 저장 위치 · 이름 규칙 (2026-10-18). 처음에는 예전 볼트 폴더에서 찾을 수 있는 만큼 옮긴다
    var vaultPaths: VaultPaths {
        didSet {
            defaults.set(try? JSONEncoder().encode(vaultPaths), forKey: Key.vaultPaths)
            onVaultPathChange?()
        }
    }

    /// 위치 · 이름 규칙이 바뀌면 카드가 12.0을 다시 읽는다
    @ObservationIgnored var onVaultPathChange: (@MainActor () -> Void)?

    /// 역할별 세션 이름. 처음에는 기본 이름(Brain_of_Pine/JobAnalysis · Resume · Application)
    var sessionRoster: SessionRoster {
        didSet { defaults.set(try? JSONEncoder().encode(sessionRoster), forKey: Key.sessionRoster) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // 예전 설정(볼트 폴더 하나)은 처음 한 번 항목별 위치로 옮길 때만 읽는다
        let legacy = defaults.string(forKey: Key.vaultPath)
        vaultPaths = defaults.data(forKey: Key.vaultPaths)
            .flatMap { try? JSONDecoder().decode(VaultPaths.self, from: $0) }
            ?? legacy.flatMap { VaultPaths.detected(vault: URL(fileURLWithPath: $0, isDirectory: true)) }
            ?? VaultPaths(statusFile: "", postingFolder: "", outputFolder: "", ownerName: "")
        sessionRoster = defaults.data(forKey: Key.sessionRoster)
            .flatMap { try? JSONDecoder().decode(SessionRoster.self, from: $0) }?
            .migratingLegacyDefaults() ?? .defaults
    }
}
