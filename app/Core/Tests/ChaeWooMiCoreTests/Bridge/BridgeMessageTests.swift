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
        #expect(page == .jobPage(
            site: "saramin",
            url: "https://www.saramin.co.kr/zf_user/jobs/relay/view?rec_idx=12345678",
            company: "가상전자(주)"
        ))
    }

    @Test("앱이 보내는 응답은 예시와 같은 JSON이다")
    func encodesAckLikeExample() throws {
        let encoded = try JSONEncoder().encode(AppToExtension.ack(appVersion: "0.1.0"))
        let mine = try JSONSerialization.jsonObject(with: encoded) as? NSDictionary
        let expected = try JSONSerialization.jsonObject(with: example("ack.json")) as? NSDictionary
        #expect(mine == expected)
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

    @Test("회사명 없는 공고 메시지도 주고받는다")
    func jobPageWithoutCompany() throws {
        let message = ExtensionToApp.jobPage(site: "wanted", url: "https://www.wanted.co.kr/wd/1", company: nil)
        let data = try JSONEncoder().encode(message)
        #expect(try JSONDecoder().decode(ExtensionToApp.self, from: data) == message)
        #expect(String(bytes: data, encoding: .utf8)?.contains("company") == false)
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
