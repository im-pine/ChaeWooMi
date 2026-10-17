import ChaeWooMiCore
import Foundation
import Observation

/// Chrome 확장과의 연결 허브. 호스트 등록 파일을 설치하고 앱 소켓을 열어 확장 메시지를 받는다.
@MainActor
@Observable
final class BrowserBridge {
    private(set) var registration: NativeHostManifest.Registration = .missing
    private(set) var connections = ExtensionConnections()
    private(set) var serverError: String?
    /// 지원 사이트 설정 (WEB-014). 파일이 틀렸으면 기본값으로 동작하고 problems에 이유를 담는다
    private(set) var siteConfig = SiteConfigStore.Loaded(config: .defaultConfig, problems: [])
    /// 공고 · 이동 · 지원 버튼 알림을 받을 곳 (카드)
    @ObservationIgnored var onPage: (@MainActor (ExtensionToApp) -> Void)?

    private var server: BridgeServer?
    private var nextConnectionID = 0

    var status: BrowserConnectionStatus {
        .resolve(
            registration: registration,
            extensionVersion: connections.currentVersion,
            everConnected: connections.everConnected
        )
    }

    /// 호스트 실행 파일은 앱 번들의 `Contents/MacOS/chaewoomi-host` (project.yml 빌드 스크립트가 복사)
    private var expectedManifest: NativeHostManifest {
        let host = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/chaewoomi-host")
        return NativeHostManifest(hostPath: host.path)
    }

    func start() {
        siteConfig = SiteConfigStore.load(from: SiteConfigStore.defaultURL())
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
                Task { await self.accept(connection) }
            }
            self.server = server
        } catch {
            serverError = "앱 소켓을 열지 못했습니다: \(error)"
        }
    }

    private func accept(_ connection: BridgeConnection) {
        nextConnectionID += 1
        let id = nextConnectionID
        connections.opened(id)
        Task { await BrowserBridge.serve(connection, id: id, bridge: self) }
    }

    /// 연결 하나의 메시지를 끝날 때까지 처리한다
    private nonisolated static func serve(_ connection: BridgeConnection, id: Int, bridge: BrowserBridge) async {
        for await line in connection.lines {
            guard let message = try? JSONDecoder().decode(ExtensionToApp.self, from: Data(line.utf8)) else {
                continue
            }
            await bridge.handle(message, from: connection, id: id)
        }
        await bridge.connectionClosed(id)
    }

    private func handle(_ message: ExtensionToApp, from connection: BridgeConnection, id: Int) {
        switch message {
        case let .hello(version):
            connections.hello(id, version: version)
            try? connection.send(AppToExtension.ack(appVersion: Self.appVersion))
            try? connection.send(AppToExtension.siteConfig(siteConfig.config))
        case .jobPage, .pageLeft, .applyButton, .applyComplete:
            onPage?(message)
        }
    }

    private func connectionClosed(_ id: Int) {
        connections.closed(id)
    }

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
}
