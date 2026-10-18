import Foundation

/// 브라우저 연결에 쓰는 고정 이름 · 경로
public enum BridgePaths {
    /// Native Messaging 호스트 이름 (확장 `NATIVE_HOST`와 같아야 함)
    public static let hostName = "com.impine.chaewoomi"
    /// manifest `key`로 고정한 확장 ID
    public static let extensionID = "abceklimfjcabkeahgahfakmajlimbem"
    public static let appBundleID = "com.impine.chaewoomi"

    /// 앱 소켓 (`~/Library/Application Support/ChaeWooMi/bridge.sock`)
    public static func socket(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home.appendingPathComponent("Library/Application Support/ChaeWooMi/bridge.sock")
    }

    /// Chrome 호스트 등록 파일
    public static func chromeHostManifest(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home.appendingPathComponent("Library/Application Support/Google/Chrome/NativeMessagingHosts/\(hostName).json")
    }
}
