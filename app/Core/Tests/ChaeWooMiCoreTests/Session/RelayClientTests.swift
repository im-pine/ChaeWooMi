import Foundation
import Testing
@testable import ChaeWooMiCore

/// 실제 Claude 대신 쓰는 가짜 중계 세션. 요청 줄의 받는 세션 이름을 보고 정해진 사건을 출력한다.
private let fakeRelayScript = #"""
#!/bin/sh
say() { printf '{"type":"assistant","message":{"content":[{"type":"text","text":"CHAEWOOMI %s"}]}}\n' "$1"; }
while IFS= read -r line; do
  case "$line" in
    *'\"op\":\"list\"'*) say '{\"event\":\"agents\",\"names\":[\"job-analysis\",\"resume\"]}' ;;
    *'\"to\":\"resume\"'*)
      say '{\"event\":\"sent\",\"id\":\"r1\"}'
      say '{\"event\":\"reply\",\"from\":\"resume\",\"text\":\"done r1\"}' ;;
    *'\"to\":\"nobody\"'*) say '{\"event\":\"not_sent\",\"id\":\"r2\",\"reason\":\"session not found\"}' ;;
    *'\"to\":\"quit\"'*) exit 0 ;;
    *) ;;
  esac
done
"""#

private struct FakeRelay: ~Copyable {
    let folder: URL
    let client: RelayClient

    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("chaewoomi-relay-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let script = folder.appendingPathComponent("fake-claude")
        try fakeRelayScript.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        client = RelayClient(launch: RelayLaunch(executable: script, workingDirectory: folder))
    }

    deinit {
        try? FileManager.default.removeItem(at: folder)
    }
}

@Suite("중계 세션 연동 (가짜 중계 세션)")
struct RelayClientTests {
    @Test("요청을 보내면 보냄 확인을 받고 역할 세션 회신이 회신 흐름으로 온다")
    func sendAndReply() async throws {
        let relay = try FakeRelay()
        try await relay.client.start()

        try await relay.client.send(id: "r1", to: "resume", text: "가상전자(주) 이력서")
        var replies = relay.client.replies.makeAsyncIterator()
        let reply = await replies.next()

        #expect(reply == RelayClient.Reply(from: "resume", text: "done r1"))
        await relay.client.stop()
    }

    @Test("받는 세션이 없으면 못 보냄 오류와 이유를 돌려준다")
    func notSent() async throws {
        let relay = try FakeRelay()
        try await relay.client.start()

        await #expect(throws: RelayClient.RelayError.notSent(reason: "session not found")) {
            try await relay.client.send(id: "r2", to: "nobody", text: "시험")
        }
        await relay.client.stop()
    }

    @Test("세션 목록을 받는다")
    func listSessions() async throws {
        let relay = try FakeRelay()
        try await relay.client.start()

        #expect(try await relay.client.listSessions() == ["job-analysis", "resume"])
        await relay.client.stop()
    }

    @Test("중계 세션이 답하지 않으면 시간 초과")
    func timeout() async throws {
        let relay = try FakeRelay()
        try await relay.client.start()

        await #expect(throws: RelayClient.RelayError.timedOut) {
            try await relay.client.send(id: "r3", to: "silent", text: "시험", timeout: .milliseconds(300))
        }
        await relay.client.stop()
    }

    @Test("중계 세션이 끝나면 대기 중인 요청은 실행 안 됨 오류")
    func processEnds() async throws {
        let relay = try FakeRelay()
        try await relay.client.start()

        await #expect(throws: RelayClient.RelayError.notRunning) {
            try await relay.client.send(id: "r4", to: "quit", text: "시험")
        }
    }

    @Test("시작하지 않았으면 요청을 보내지 않고 실행 안 됨 오류")
    func notStarted() async throws {
        let relay = try FakeRelay()
        await #expect(throws: RelayClient.RelayError.notRunning) {
            try await relay.client.listSessions()
        }
    }

    @Test("실행 파일이 없으면 시작 실패")
    func launchFails() async {
        let launch = RelayLaunch(
            executable: URL(fileURLWithPath: "/nonexistent/claude"),
            workingDirectory: FileManager.default.temporaryDirectory
        )
        await #expect(throws: RelayClient.RelayError.self) {
            try await RelayClient(launch: launch).start()
        }
    }
}
