import Foundation

/// 호스트가 앱 소켓에 연결한다. 앱이 꺼져 있으면 실행하지 않고 켜질 때까지 기다린다 — 앱은 사용자가 켠다.
/// 확장이 공고 페이지 확인창에서 "열기"를 고르면(`launchApp`) 그때만 `openApp`으로 실행한다.
public enum HostLauncher {
    /// 연결될 때까지 `interval`마다 다시 시도한다. 첫 시도가 실패하면 `onWaiting`을 한 번 부른다
    public static func waitForApp(
        socketPath: String,
        interval: Duration = .milliseconds(500),
        onWaiting: () -> Void
    ) async -> BridgeConnection {
        if let connection = try? BridgeConnection.connect(path: socketPath) { return connection }
        onWaiting()
        while true {
            try? await Task.sleep(for: interval)
            if let connection = try? BridgeConnection.connect(path: socketPath) { return connection }
        }
    }

    /// `open -b <번들 ID>`: 사용자가 확인창에서 고른 실행이므로 앱을 앞으로 가져온다
    public static func openApp(bundleID: String = BridgePaths.appBundleID) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-b", bundleID]
        try? process.run()
        process.waitUntilExit()
    }
}
