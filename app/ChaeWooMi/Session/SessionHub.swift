import ChaeWooMiCore
import Foundation
import Observation

/// 역할 세션 연결 상태와 요청 전달. 중계 세션(`claude -p`)은 처음 필요할 때 띄운다.
@MainActor
@Observable
final class SessionHub {
    private(set) var listed: [String]?
    private(set) var lastError: String?
    private(set) var checking = false

    private var relay: RelayClient?

    func availability(of role: SessionRole, roster: SessionRoster) -> SessionAvailability? {
        guard let listed else { return nil }
        return .resolve(role: role, roster: roster, listed: listed)
    }

    /// 중계 세션에 세션 목록을 물어 연결 상태를 갱신한다
    func refresh() async {
        checking = true
        defer { checking = false }
        do {
            listed = try await startedRelay().listSessions()
            lastError = nil
        } catch {
            // 이전 목록으로 연결됨이라 판정해 요청을 보내지 않도록 비운다
            listed = nil
            lastError = Self.describe(error)
        }
    }

    /// 받는 세션이 열려 있을 때만 요청을 보낸다. 꺼져 있으면 보내지 않고 안내를 돌려준다
    func send(_ text: String, to role: SessionRole, roster: SessionRoster) async -> String? {
        await refresh()
        guard let listed else { return lastError }
        switch SessionRequestGate.decide(role: role, roster: roster, listed: listed) {
        case let .refuse(guidance):
            return guidance
        case let .send(sessionName):
            do {
                try await startedRelay().send(id: UUID().uuidString, to: sessionName, text: text)
                return nil
            } catch {
                return Self.describe(error)
            }
        }
    }

    func stop() {
        guard let relay else { return }
        Task { await relay.stop() }
        self.relay = nil
    }

    /// 중계 세션이 끝났으면(로그인 만료 · 비정상 종료) 다시 띄운다
    private func startedRelay() async throws -> RelayClient {
        if let relay, await relay.isRunning { return relay }
        relay = nil
        guard let executable = RelayLaunch.findExecutable() else { throw HubError.claudeNotFound }
        let folder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ChaeWooMi/relay", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let client = RelayClient(launch: RelayLaunch(executable: executable, workingDirectory: folder))
        try await client.start()
        relay = client
        return client
    }

    private enum HubError: Error {
        case claudeNotFound
    }

    private static func describe(_ error: any Error) -> String {
        switch error {
        case HubError.claudeNotFound:
            "Claude Code(`claude`)를 찾지 못했습니다. ~/.local/bin 또는 /opt/homebrew/bin에 설치하세요"
        case RelayClient.RelayError.timedOut:
            "중계 세션이 응답하지 않습니다. 잠시 뒤 다시 확인하세요"
        case let RelayClient.RelayError.notSent(reason):
            "요청을 보내지 못했습니다: \(reason)"
        case RelayClient.RelayError.notRunning, RelayClient.RelayError.launchFailed:
            "중계 세션을 실행하지 못했습니다. Claude Code 로그인 상태를 확인하세요"
        default:
            "세션 연결 확인 실패: \(error.localizedDescription)"
        }
    }
}
