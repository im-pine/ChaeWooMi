import Foundation

/// 호스트가 꺼진 앱을 실행해도 되는가. 확장이 스스로 다시 연결할 때는 첫 인사에 `"quiet": true`를 붙이고,
/// 호스트는 그때 앱을 실행하지 않는다 — 사용자가 일부러 끈 앱이 주기적 재연결로 다시 켜지지 않게.
/// 공고를 열어 보낼 알림이 생긴 연결(첫 인사에 quiet 없음)은 지금처럼 앱을 실행한다 (APP-019)
public enum HostLaunchHint {
    public static func isQuiet(_ firstMessage: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: firstMessage) as? [String: Any] else { return false }
        return object["type"] as? String == "hello" && object["quiet"] as? Bool == true
    }
}
