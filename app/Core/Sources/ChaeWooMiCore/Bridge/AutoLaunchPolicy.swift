import Foundation

/// 공고 진입 시 자동 실행 (APP-019 · APP-005). 앱 메뉴바 스위치 값을 앱과 호스트가 같이 읽는다.
public enum AutoLaunchPolicy {
    /// 앱 UserDefaults 키 (기본 켜짐)
    public static let key = "autoLaunchFromBrowser"

    /// 앱이 꺼져 있을 때 호스트가 앱을 실행해도 되는가
    public static func isEnabled(_ defaults: UserDefaults?) -> Bool {
        guard let defaults, defaults.object(forKey: key) != nil else { return true }
        return defaults.bool(forKey: key)
    }

    /// 호스트(다른 프로세스)가 읽는 앱 설정 영역
    public static func appDefaults(bundleID: String = BridgePaths.appBundleID) -> UserDefaults? {
        UserDefaults(suiteName: bundleID)
    }
}
