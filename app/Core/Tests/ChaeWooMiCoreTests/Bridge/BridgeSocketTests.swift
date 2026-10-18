import Foundation
import Testing
@testable import ChaeWooMiCore

/// sun_path 길이 제한(104바이트) 안에 드는 임시 소켓 경로
private func temporarySocketPath() -> String {
    "/tmp/cwm-\(UUID().uuidString.prefix(8)).sock"
}

@Suite("앱 소켓 (호스트 ↔ 앱)")
struct BridgeSocketTests {
    @Test("호스트가 보낸 줄을 앱이 받고, 앱 응답을 호스트가 받는다")
    func exchangeLines() async throws {
        let path = temporarySocketPath()
        let server = try BridgeServer(path: path)
        defer { server.stop() }
        server.start { connection in
            Task {
                for await line in connection.lines {
                    if let message = try? JSONDecoder().decode(ExtensionToApp.self, from: Data(line.utf8)),
                       case .hello = message {
                        try connection.send(AppToExtension.ack(appVersion: "9.9.9"))
                    }
                }
            }
        }

        let host = try BridgeConnection.connect(path: path)
        try host.send(ExtensionToApp.hello(extensionVersion: "0.1.0"))
        var lines = host.lines.makeAsyncIterator()
        let reply = await lines.next()

        let ack = try JSONDecoder().decode(AppToExtension.self, from: Data((reply ?? "").utf8))
        #expect(ack == .ack(appVersion: "9.9.9"))
        host.close()
    }

    @Test("소켓 파일은 같은 사용자만 읽고 쓸 수 있다 (0600)")
    func ownerOnly() throws {
        let path = temporarySocketPath()
        let server = try BridgeServer(path: path)
        defer { server.stop() }
        let permissions = try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? Int
        #expect(permissions == 0o600)
    }

    @Test("앱이 꺼져 있으면(소켓 없음) 연결 오류")
    func noServer() {
        #expect(throws: UnixSocketError.self) { try BridgeConnection.connect(path: temporarySocketPath()) }
    }

    @Test("서버를 멈추면 소켓 파일을 지운다")
    func stopRemovesFile() throws {
        let path = temporarySocketPath()
        try BridgeServer(path: path).stop()
        #expect(!FileManager.default.fileExists(atPath: path))
    }

    @Test("소켓 경로가 너무 길면 거부한다")
    func pathTooLong() {
        #expect(throws: UnixSocketError.pathTooLong) {
            try BridgeServer(path: "/tmp/" + String(repeating: "a", count: 120))
        }
    }

    @Test("한 줄 메시지에 줄바꿈이 들어 있으면 보내지 않는다")
    func refusesNewlineInLine() async throws {
        let path = temporarySocketPath()
        let server = try BridgeServer(path: path)
        defer { server.stop() }
        let received = AsyncStream<String>.makeStream()
        server.start { connection in
            Task { for await line in connection.lines { received.continuation.yield(line) } }
        }
        let host = try BridgeConnection.connect(path: path)
        try host.send(line: Data("a\nb".utf8))
        try host.send(line: Data("ok".utf8))
        var iterator = received.stream.makeAsyncIterator()
        #expect(await iterator.next() == "ok")
        host.close()
    }

    @Test("앱이 꺼져 있으면 실행을 부탁하고 소켓이 열리면 연결한다")
    func launcherStartsApp() async throws {
        let path = temporarySocketPath()
        let started = ServerBox()
        let connection = await HostLauncher.connect(socketPath: path, launchApp: {
            started.server = try? BridgeServer(path: path)
        }, timeout: .seconds(2), interval: .milliseconds(50))
        defer { started.server?.stop() }

        #expect(started.server != nil)
        #expect(connection != nil)
    }

    @Test("앱이 끝내 소켓을 열지 않으면 시간 초과 후 nil")
    func launcherTimesOut() async {
        let connection = await HostLauncher.connect(
            socketPath: temporarySocketPath(),
            launchApp: {},
            timeout: .milliseconds(200),
            interval: .milliseconds(50)
        )
        #expect(connection == nil)
    }
}

private final class ServerBox: @unchecked Sendable {
    var server: BridgeServer?
}
