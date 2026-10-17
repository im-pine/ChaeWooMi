import Foundation
import Testing
@testable import ChaeWooMiCore

/// 실측한 중계 세션 stream-json 출력 모양 (글자 블록 하나)
private func assistantLine(_ text: String) throws -> String {
    let object: [String: Any] = ["type": "assistant", "message": ["content": [["type": "text", "text": text]]]]
    return String(bytes: try JSONSerialization.data(withJSONObject: object), encoding: .utf8) ?? ""
}

@Suite("중계 규약")
struct RelayProtocolTests {
    @Test("전달 요청은 stream-json 사용자 메시지 한 줄이고 요청 글자를 그대로 담는다")
    func sendRequestLine() throws {
        let text = "[채우미] 가상전자(주) 이력서 \"초안\"\n둘째 줄"
        let line = RelayRequest.send(id: "r1", session: "resume", text: text).inputLine()

        #expect(line.hasSuffix("\n"))
        #expect(line.dropLast().contains("\n") == false)
        let object = try #require(try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
        let message = try #require(object["message"] as? [String: Any])
        let content = try #require(message["content"] as? String)
        let payload = try #require(try JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: String])
        #expect(object["type"] as? String == "user")
        #expect(payload == ["op": "send", "id": "r1", "to": "resume", "text": text])
    }

    @Test("중계 세션 출력에서 보냄 · 못 보냄 · 목록 · 회신 사건을 꺼낸다")
    func parsesEvents() throws {
        let lines = [
            #"CHAEWOOMI {"event":"sent","id":"r1"}"#,
            #"CHAEWOOMI {"event":"not_sent","id":"r2","reason":"session not found"}"#,
            #"CHAEWOOMI {"event":"agents","id":"l1","names":["job-analysis","resume"]}"#,
            #"CHAEWOOMI {"event":"reply","from":"resume","text":"done r1\n파일 생성"}"#
        ]
        let events = try lines.flatMap { RelayOutputParser.events(fromStreamLine: try assistantLine($0)) }
        #expect(events == [
            .sent(id: "r1"),
            .notSent(id: "r2", reason: "session not found"),
            .agents(id: "l1", names: ["job-analysis", "resume"]),
            .reply(from: "resume", text: "done r1\n파일 생성")
        ])
    }

    @Test("한 글자 블록에 여러 줄이 있으면 표시 줄만 사건으로 읽는다")
    func multipleLinesInBlock() throws {
        let text = "잡담\nCHAEWOOMI {\"event\":\"sent\",\"id\":\"a\"}\nCHAEWOOMI {\"event\":\"sent\",\"id\":\"b\"}"
        #expect(RelayOutputParser.events(fromStreamLine: try assistantLine(text)) == [.sent(id: "a"), .sent(id: "b")])
    }

    @Test("result · system 줄, 표시 없는 글자, 깨진 JSON은 사건이 아니다")
    func ignoresOtherLines() throws {
        let result = #"{"type":"result","result":"CHAEWOOMI {\"event\":\"sent\",\"id\":\"r1\"}"}"#
        #expect(RelayOutputParser.events(fromStreamLine: result).isEmpty)
        #expect(RelayOutputParser.events(fromStreamLine: #"{"type":"system","subtype":"init"}"#).isEmpty)
        #expect(RelayOutputParser.events(fromStreamLine: try assistantLine("보냈습니다")).isEmpty)
        #expect(RelayOutputParser.events(fromStreamLine: try assistantLine("CHAEWOOMI {broken")).isEmpty)
        #expect(RelayOutputParser.events(fromStreamLine: try assistantLine(#"CHAEWOOMI {"event":"sent"}"#)).isEmpty)
        let agentsWithoutID = #"CHAEWOOMI {"event":"agents","names":["resume"]}"#
        #expect(RelayOutputParser.events(fromStreamLine: try assistantLine(agentsWithoutID)).isEmpty)
        #expect(RelayOutputParser.events(fromStreamLine: "not json").isEmpty)
    }

    @Test("목록 요청에는 응답을 맞춰 볼 id가 들어간다")
    func listRequestHasID() throws {
        let line = RelayRequest.list(id: "l7").inputLine()
        let object = try #require(try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
        let content = try #require((object["message"] as? [String: Any])?["content"] as? String)
        #expect(content == #"{"id":"l7","op":"list"}"#)
    }

    @Test("중계 세션은 받은 메시지를 승인 없이 받고 SendMessage · ListAgents만 쓴다")
    func launchArguments() {
        let launch = RelayLaunch(
            executable: URL(fileURLWithPath: "/bin/claude"),
            workingDirectory: URL(fileURLWithPath: "/tmp")
        )
        let args = launch.arguments
        let settingsIndex = args.firstIndex(of: "--settings").map { $0 + 1 }
        #expect(settingsIndex.map { args[$0] } == #"{"crossSessionInbound":"accept"}"#)
        #expect(args.contains("chaewoomi-relay"))
        let toolsIndex = args.firstIndex(of: "--tools").map { $0 + 1 }
        #expect(toolsIndex.map { args[$0] } == "SendMessage,ListAgents")
        #expect(!args.contains("--disallowedTools"))
        #expect(args.contains("--strict-mcp-config"))
        #expect(!args.contains("--mcp-config"))
    }

    @Test("claude 실행 파일을 흔한 설치 위치 순서대로 찾는다")
    func findsExecutable() {
        let home = URL(fileURLWithPath: "/Users/tester")
        let installed: Set = ["/opt/homebrew/bin/claude", "/usr/local/bin/claude"]
        let found = RelayLaunch.findExecutable(home: home) { installed.contains($0) }
        #expect(found?.path == "/opt/homebrew/bin/claude")
        #expect(RelayLaunch.findExecutable(home: home) { _ in false } == nil)
    }
}
