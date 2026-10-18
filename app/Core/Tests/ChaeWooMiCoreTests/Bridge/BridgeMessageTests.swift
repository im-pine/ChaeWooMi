import Foundation
import Testing
@testable import ChaeWooMiCore

/// 저장소 루트 `protocol/examples` (확장 Vitest와 같은 파일)
private func example(_ name: String) throws -> Data {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    return try Data(contentsOf: root.appendingPathComponent("protocol/examples/\(name)"))
}

@Suite("확장 ↔ 앱 메시지 규약 (공용 예시)")
struct BridgeMessageTests {
    @Test("확장이 보내는 예시를 해석한다")
    func decodesExtensionExamples() throws {
        let decoder = JSONDecoder()
        let hello = try decoder.decode(ExtensionToApp.self, from: example("hello.json"))
        #expect(hello == .hello(extensionVersion: "0.1.0"))
        let page = try decoder.decode(ExtensionToApp.self, from: example("job-page.json"))
        #expect(page == .jobPage(JobPage(
            site: "saramin",
            url: "https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=12345678",
            companies: ["가상전자(주)"],
            title: "[가상전자(주)] 프론트엔드 개발자 채용",
            postingText: "담당업무 웹 프론트엔드 개발 자격요건 TypeScript 경험"
        )))
        #expect(try decoder.decode(ExtensionToApp.self, from: example("page-left.json")) == .pageLeft)
        let apply = try decoder.decode(ExtensionToApp.self, from: example("apply-button.json"))
        #expect(apply == .applyButton(covering: true))
        #expect(try decoder.decode(ExtensionToApp.self, from: example("not-posting.json")) == .notPosting)
        let complete = try decoder.decode(ExtensionToApp.self, from: example("apply-complete.json"))
        #expect(complete == .applyComplete(JobPage(
            site: "wanted",
            url: "https://www.wanted.co.kr/wd/300001",
            companies: ["가상전자(주)"],
            title: "[가상전자(주)] 프론트엔드 개발자"
        )))
    }

    @Test("앱이 보내는 응답은 예시와 같은 JSON이다")
    func encodesAckLikeExample() throws {
        let encoded = try JSONEncoder().encode(AppToExtension.ack(appVersion: "0.1.0"))
        let mine = try JSONSerialization.jsonObject(with: encoded) as? NSDictionary
        let expected = try JSONSerialization.jsonObject(with: example("ack.json")) as? NSDictionary
        #expect(mine == expected)
    }

    @Test("다시 읽기 요청은 예시와 같은 JSON이다")
    func encodesRescanLikeExample() throws {
        let encoded = try JSONEncoder().encode(AppToExtension.rescan(reload: false))
        let mine = try JSONSerialization.jsonObject(with: encoded) as? NSDictionary
        let expected = try JSONSerialization.jsonObject(with: example("rescan.json")) as? NSDictionary
        #expect(mine == expected)
        #expect(try JSONDecoder().decode(AppToExtension.self, from: example("rescan.json")) == .rescan(reload: false))
        let reload = try JSONDecoder().decode(AppToExtension.self, from: example("rescan-reload.json"))
        #expect(reload == .rescan(reload: true))
        let reencoded = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(reload)) as? NSDictionary
        let expectedReload = try JSONSerialization.jsonObject(with: example("rescan-reload.json")) as? NSDictionary
        #expect(reencoded == expectedReload)
    }

    @Test("모르는 type · 필수 필드 없음은 해석하지 않는다")
    func rejectsInvalid() {
        let decoder = JSONDecoder()
        let unknown = Data(#"{"type":"x"}"#.utf8)
        let helloWithoutVersion = Data(#"{"type":"hello"}"#.utf8)
        #expect(throws: DecodingError.self) { try decoder.decode(ExtensionToApp.self, from: unknown) }
        #expect(throws: DecodingError.self) { try decoder.decode(ExtensionToApp.self, from: helloWithoutVersion) }
        #expect(throws: DecodingError.self) { try decoder.decode(AppToExtension.self, from: helloWithoutVersion) }
    }

    @Test("회사명 후보 · 원문이 없는 공고 메시지도 주고받고, 없는 필드는 쓰지 않는다")
    func jobPageWithoutCompany() throws {
        let page = JobPage(site: "wanted", url: "https://www.wanted.co.kr/wd/1", companies: [])
        let message = ExtensionToApp.jobPage(page)
        let data = try JSONEncoder().encode(message)
        #expect(try JSONDecoder().decode(ExtensionToApp.self, from: data) == message)
        let text = String(bytes: data, encoding: .utf8) ?? ""
        #expect(!text.contains("postingText"))
        #expect(text.contains(#""type":"jobPage""#))
    }
}

@Suite("Native Messaging 틀")
struct NativeMessageFramingTests {
    @Test("4바이트 리틀 엔디언 길이 + JSON으로 감싸고 다시 꺼낸다")
    func roundTrip() throws {
        let json = Data(#"{"type":"ack","appVersion":"0.1.0"}"#.utf8)
        var buffer = try NativeMessageFraming.frame(json)
        #expect(Array(buffer.prefix(4)) == [UInt8(json.count), 0, 0, 0])
        #expect(NativeMessageFraming.takeMessage(from: &buffer) == json)
        #expect(buffer.isEmpty)
    }

    @Test("덜 온 메시지는 꺼내지 않고 버퍼를 그대로 둔다")
    func partial() throws {
        let framed = try NativeMessageFraming.frame(Data("{\"a\":1}".utf8))
        var buffer = framed.prefix(6)
        #expect(NativeMessageFraming.takeMessage(from: &buffer) == nil)
        #expect(buffer.count == 6)
    }

    @Test("이어 붙은 두 메시지를 차례로 꺼낸다")
    func twoMessages() throws {
        var buffer = try NativeMessageFraming.frame(Data("1".utf8)) + NativeMessageFraming.frame(Data("22".utf8))
        #expect(NativeMessageFraming.takeMessage(from: &buffer) == Data("1".utf8))
        #expect(NativeMessageFraming.takeMessage(from: &buffer) == Data("22".utf8))
    }

    @Test("Chrome으로 보내는 메시지가 1MB를 넘으면 거부한다")
    func tooLarge() {
        let big = Data(count: NativeMessageFraming.maxOutgoingBytes + 1)
        #expect(throws: NativeMessageFraming.FramingError.tooLarge(big.count)) {
            try NativeMessageFraming.frame(big)
        }
    }

    @Test("표준 입력 같은 스트림에서 메시지를 읽고 끝나면 nil")
    func readsFromHandle() throws {
        let pipe = Pipe()
        let first = Data(#"{"type":"hello","extensionVersion":"0.1.0"}"#.utf8)
        try pipe.fileHandleForWriting.write(contentsOf: try NativeMessageFraming.frame(first))
        try pipe.fileHandleForWriting.close()
        #expect(NativeMessageFraming.readMessage(from: pipe.fileHandleForReading) == first)
        #expect(NativeMessageFraming.readMessage(from: pipe.fileHandleForReading) == nil)
    }
}

@Suite("호스트의 앱 실행 판단")
struct HostLaunchHintTests {
    @Test("확장이 스스로 다시 연결한 인사(quiet)면 앱을 실행하지 않고, 보통 인사 · 다른 메시지는 실행해도 된다")
    func quietHello() {
        #expect(HostLaunchHint.isQuiet(Data(#"{"type":"hello","extensionVersion":"0.2.0","quiet":true}"#.utf8)))
        #expect(!HostLaunchHint.isQuiet(Data(#"{"type":"hello","extensionVersion":"0.2.0"}"#.utf8)))
        #expect(!HostLaunchHint.isQuiet(Data(#"{"type":"hello","quiet":false}"#.utf8)))
        #expect(!HostLaunchHint.isQuiet(Data(#"{"type":"jobPage","quiet":true}"#.utf8)))
        #expect(!HostLaunchHint.isQuiet(Data("not json".utf8)))
    }
}
