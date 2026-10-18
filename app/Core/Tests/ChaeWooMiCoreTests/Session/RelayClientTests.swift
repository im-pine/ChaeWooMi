import Foundation
import Testing
@testable import ChaeWooMiCore

/// 실제 Claude 대신 쓰는 가짜 중계 세션. 요청 줄의 받는 세션 이름을 보고 정해진 사건을 출력한다.
private let fakeRelayScript = #"""
#!/bin/sh
say() { printf '{"type":"assistant","message":{"content":[{"type":"text","text":"CHAEWOOMI %s"}]}}\n' "$1"; }
lists=0
while IFS= read -r line; do
  case "$line" in
    *'\"op\":\"list\"'*)
      lists=$((lists + 1))
      id=$(printf '%s' "$line" |
        sed -n 's/.*\\"id\\":\\"\([^\\]*\)\\".*/\1/p')
      # 첫 목록 요청만 1초 늦게 답한다 (시간 초과 뒤 늦은 응답 시험)
      if [ "$lists" -eq 1 ] && [ -n "$SLOW_FIRST_LIST" ]; then sleep 1; fi
      # 첫 목록 요청에 목록 대신 막 도착한 회신 한 줄만 출력한다 (실측한 중계 모델 동작)
      if [ "$lists" -eq 1 ] && [ -n "$DROP_FIRST_LIST" ]; then
        say '{\"event\":\"reply\",\"from\":\"job-analysis\",\"text\":\"[채우미 회신] id=a-1 결과=완료\"}'
        continue
      fi
      names="[\\\"job-analysis\\\",\\\"n$lists\\\"]"
      say "{\\\"event\\\":\\\"agents\\\",\\\"id\\\":\\\"$id\\\",\\\"names\\\":$names}" ;;
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

    /// `prelude`는 스크립트 맨 앞(셔뱅 다음)에 들어가는 셸 줄 (동작을 바꾸는 시험용)
    init(prelude: String = "") throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("chaewoomi-relay-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let script = folder.appendingPathComponent("fake-claude")
        let source = fakeRelayScript.replacingOccurrences(of: "#!/bin/sh\n", with: "#!/bin/sh\n\(prelude)\n")
        try source.write(to: script, atomically: true, encoding: .utf8)
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

        #expect(try await relay.client.listSessions() == ["job-analysis", "n1"])
        await relay.client.stop()
    }

    @Test("시간 초과된 목록 요청의 늦은 응답은 다음 목록 요청에 붙지 않는다")
    func lateListReplyIgnored() async throws {
        let relay = try FakeRelay(prelude: "SLOW_FIRST_LIST=1")
        try await relay.client.start()

        await #expect(throws: RelayClient.RelayError.timedOut) {
            try await relay.client.listSessions(timeout: .milliseconds(300), attempts: 1)
        }
        #expect(try await relay.client.listSessions() == ["job-analysis", "n2"])
        await relay.client.stop()
    }

    @Test("목록 응답을 빠뜨리면 다시 물어 목록을 받는다 (회신과 목록 요청이 겹친 실측 버그)")
    func listRetriedWhenDropped() async throws {
        let relay = try FakeRelay(prelude: "DROP_FIRST_LIST=1")
        try await relay.client.start()
        var replies = relay.client.replies.makeAsyncIterator()

        // 기계가 바쁘면 두 번째 응답도 늦어 세 번째를 받을 수 있다 → 다시 물은 결과(n1이 아님)인지만 본다
        let names = try await relay.client.listSessions(timeout: .seconds(1))
        #expect(names.first == "job-analysis")
        #expect(names.count == 2 && names[1] != "n1")
        // 빠뜨린 대신 출력한 회신은 회신 흐름으로 그대로 온다
        #expect(await replies.next()?.from == "job-analysis")
        await relay.client.stop()
    }

    @Test("같은 id의 요청이 진행 중이면 두 번째는 바로 거부한다")
    func duplicateID() async throws {
        let relay = try FakeRelay()
        try await relay.client.start()
        let client = relay.client

        let first = Task { try await client.send(id: "same", to: "silent", text: "a", timeout: .seconds(2)) }
        try await Task.sleep(for: .milliseconds(100))
        await #expect(throws: RelayClient.RelayError.duplicateID) {
            try await client.send(id: "same", to: "silent", text: "b")
        }
        await #expect(throws: RelayClient.RelayError.timedOut) { try await first.value }
        await client.stop()
    }

    @Test("멈춘 직후 다시 띄워도 이전 프로세스 종료가 새 연결을 지우지 않는다")
    func restartKeepsNewProcess() async throws {
        let relay = try FakeRelay()
        try await relay.client.start()
        await relay.client.stop()
        try await relay.client.start()
        try await Task.sleep(for: .milliseconds(200))

        #expect(await relay.client.isRunning)
        #expect(try await relay.client.listSessions() == ["job-analysis", "n1"])
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
