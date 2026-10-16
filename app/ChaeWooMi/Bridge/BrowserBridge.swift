import ChaeWooMiCore
import Foundation
import Observation

/// Chrome 확장과의 연결 허브. 호스트 등록 파일을 설치하고 앱 소켓을 열어 확장 메시지를 받는다.
@MainActor
@Observable
final class BrowserBridge {
    private(set) var registration: NativeHostManifest.Registration = .missing
    private(set) var extensionVersion: String?
    private(set) var everConnected = false
    private(set) var serverError: String?

    private var server: BridgeServer?

    var status: BrowserConnectionStatus {
        .resolve(registration: registration, extensionVersion: extensionVersion, everConnected: everConnected)
    }

    /// 호스트 실행 파일은 앱 번들의 `Contents/MacOS/chaewoomi-host` (project.yml 빌드 스크립트가 복사)
    private var expectedManifest: NativeHostManifest {
        let host = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/chaewoomi-host")
        return NativeHostManifest(hostPath: host.path)
    }

    func start() {
        installHostManifest()
        startServer()
    }

    func stop() {
        server?.stop()
        server = nil
    }

    func installHostManifest() {
        let url = BridgePaths.chromeHostManifest()
        try? expectedManifest.install(at: url)
        registration = NativeHostManifest.check(at: url, expected: expectedManifest)
    }

    private func startServer() {
        let socket = BridgePaths.socket()
        do {
            try FileManager.default.createDirectory(
                at: socket.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let server = try BridgeServer(path: socket.path)
            server.start { connection in
                Task { await BrowserBridge.serve(connection, bridge: self) }
            }
            self.server = server
        } catch {
            serverError = "앱 소켓을 열지 못했습니다: \(error)"
        }
    }

    /// 연결 하나의 메시지를 끝날 때까지 처리한다
    private nonisolated static func serve(_ connection: BridgeConnection, bridge: BrowserBridge) async {
        for await line in connection.lines {
            guard let message = try? JSONDecoder().decode(ExtensionToApp.self, from: Data(line.utf8)) else {
                continue
            }
            await bridge.handle(message, from: connection)
        }
        await bridge.connectionClosed()
    }

    private func handle(_ message: ExtensionToApp, from connection: BridgeConnection) {
        switch message {
        case let .hello(version):
            extensionVersion = version
            everConnected = true
            try? connection.send(AppToExtension.ack(appVersion: Self.appVersion))
        case .jobPage:
            // 공고 처리는 1단계(재지원 주의)에서 붙인다
            break
        }
    }

    private func connectionClosed() {
        extensionVersion = nil
    }

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
}
