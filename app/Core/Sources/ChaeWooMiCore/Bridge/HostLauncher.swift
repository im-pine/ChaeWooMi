import Foundation

/// 호스트가 앱 소켓에 연결한다. 앱이 꺼져 있으면 실행하고 소켓이 열릴 때까지 기다린다 (공고 진입 시 자동 실행).
public enum HostLauncher {
    public static func connect(
        socketPath: String,
        launchApp: () -> Void,
        timeout: Duration = .seconds(10),
        interval: Duration = .milliseconds(250)
    ) async -> BridgeConnection? {
        if let connection = try? BridgeConnection.connect(path: socketPath) { return connection }
        launchApp()
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            try? await Task.sleep(for: interval)
            if let connection = try? BridgeConnection.connect(path: socketPath) { return connection }
        }
        return nil
    }

    /// `open -g -b <번들 ID>`: 앱을 앞으로 가져오지 않고 실행한다
    public static func openApp(bundleID: String = BridgePaths.appBundleID) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-g", "-b", bundleID]
        try? process.run()
        process.waitUntilExit()
    }
}
