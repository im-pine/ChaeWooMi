import Testing
@testable import ChaeWooMiCore

@Suite("확장 연결 여러 개")
struct ExtensionConnectionsTests {
    @Test("새 연결이 인사한 뒤 이전 연결이 닫혀도 연결됨으로 남는다")
    func oldCloseKeepsNew() {
        var connections = ExtensionConnections()
        connections.opened(1)
        connections.hello(1, version: "0.1.0")
        connections.opened(2)
        connections.hello(2, version: "0.1.1")
        connections.closed(1)
        #expect(connections.currentVersion == "0.1.1")
    }

    @Test("가장 최근 연결이 닫히면 남은 연결의 버전을 보인다")
    func fallsBackToRemaining() {
        var connections = ExtensionConnections()
        connections.opened(1)
        connections.hello(1, version: "0.1.0")
        connections.opened(2)
        connections.hello(2, version: "0.2.0")
        connections.closed(2)
        #expect(connections.currentVersion == "0.1.0")
    }

    @Test("모든 연결이 닫히면 버전이 없고, 한 번이라도 연결됐으면 끊김으로 구분된다")
    func allClosed() {
        var connections = ExtensionConnections()
        #expect(connections.everConnected == false)
        connections.opened(1)
        connections.hello(1, version: "0.1.0")
        connections.closed(1)
        #expect(connections.currentVersion == nil)
        #expect(connections.everConnected)
    }

    @Test("인사 없이 열린 연결 · 이미 닫힌 연결의 인사는 연결로 치지 않는다")
    func helloRequired() {
        var connections = ExtensionConnections()
        connections.opened(1)
        #expect(connections.currentVersion == nil)
        connections.closed(1)
        connections.hello(1, version: "0.1.0")
        #expect(connections.currentVersion == nil)
        #expect(connections.everConnected == false)
    }
}
