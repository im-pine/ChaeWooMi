import Foundation
import Observation

/// 앱 로컬 설정. 볼트 파일이 아니라 UserDefaults에 둔다 (DB 없음 원칙).
@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let vaultPath = "vaultPath"
    }

    private let defaults: UserDefaults

    var vaultPath: String? {
        didSet { defaults.set(vaultPath, forKey: Key.vaultPath) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        vaultPath = defaults.string(forKey: Key.vaultPath)
    }
}
