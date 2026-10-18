import Foundation
import Testing
@testable import ChaeWooMiCore

@Suite("호스트 등록 파일 · 브라우저 연결 상태")
struct NativeHostManifestTests {
    private let folder = FileManager.default.temporaryDirectory.appendingPathComponent("cwm-hosts-\(UUID())")
    private var file: URL { folder.appendingPathComponent("com.impine.chaewoomi.json") }
    private let manifest = NativeHostManifest(hostPath: "/Applications/ChaeWooMi.app/Contents/MacOS/chaewoomi-host")

    @Test("등록 파일은 Chrome 규격 키와 고정 확장 ID만 허용한다")
    func manifestShape() throws {
        try manifest.install(at: file)
        defer { try? FileManager.default.removeItem(at: folder) }
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
        #expect(object?["name"] as? String == "com.impine.chaewoomi")
        #expect(object?["type"] as? String == "stdio")
        #expect(object?["path"] as? String == "/Applications/ChaeWooMi.app/Contents/MacOS/chaewoomi-host")
        let origins = object?["allowed_origins"] as? [String]
        #expect(origins == ["chrome-extension://abceklimfjcabkeahgahfakmajlimbem/"])
    }

    @Test("설치하면 등록됨, 없으면 없음")
    func installAndCheck() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(NativeHostManifest.check(at: file, expected: manifest) == .missing)
        try manifest.install(at: file)
        #expect(NativeHostManifest.check(at: file, expected: manifest) == .registered)
    }

    @Test("다른 앱 위치 · 다른 확장 ID · 깨진 파일을 구분한다")
    func mismatches() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try NativeHostManifest(hostPath: "/old/chaewoomi-host").install(at: file)
        let moved = NativeHostManifest.check(at: file, expected: manifest)
        #expect(moved == .pathMismatch(registered: "/old/chaewoomi-host"))

        try FileManager.default.removeItem(at: file)
        try NativeHostManifest(hostPath: manifest.path, extensionID: "otherid").install(at: file)
        #expect(NativeHostManifest.check(at: file, expected: manifest) == .originMismatch)

        try Data("{".utf8).write(to: file)
        #expect(NativeHostManifest.check(at: file, expected: manifest) == .unreadable)
    }

    @Test("앱 위치가 바뀌면 다시 설치할 때 고친다")
    func reinstallFixesPath() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try NativeHostManifest(hostPath: "/old/chaewoomi-host").install(at: file)
        try manifest.install(at: file)
        #expect(NativeHostManifest.check(at: file, expected: manifest) == .registered)
    }

    @Test("등록 문제가 연결 사건보다 먼저 보인다")
    func registrationFirst() {
        func resolve(_ registration: NativeHostManifest.Registration) -> BrowserConnectionStatus {
            .resolve(registration: registration, extensionVersion: "0.1.0", everConnected: true)
        }
        #expect(resolve(.missing) == .hostNotRegistered)
        #expect(resolve(.unreadable) == .hostNotRegistered)
        #expect(resolve(.pathMismatch(registered: "/x")) == .hostPathMismatch)
        #expect(resolve(.originMismatch) == .extensionNotAllowed)
    }

    @Test("등록된 뒤에는 연결됨 · 대기 · 끊김을 구분하고 안내 문구가 모두 다르다")
    func connectionStates() {
        let states: [BrowserConnectionStatus] = [
            .resolve(registration: .registered, extensionVersion: "0.1.0", everConnected: true),
            .resolve(registration: .registered, extensionVersion: nil, everConnected: false),
            .resolve(registration: .registered, extensionVersion: nil, everConnected: true),
            .hostNotRegistered, .hostPathMismatch, .extensionNotAllowed
        ]
        #expect(states[0] == .connected(extensionVersion: "0.1.0"))
        #expect(states[1] == .waitingForExtension)
        #expect(states[2] == .disconnected)
        #expect(Set(states.map(\.guidance)).count == 6)
        #expect(states.filter { !$0.isProblem } == [.connected(extensionVersion: "0.1.0")])
    }
}
