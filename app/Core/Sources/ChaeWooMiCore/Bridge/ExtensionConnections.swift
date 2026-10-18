/// 열린 확장 연결들. 연결이 둘 이상이어도(다시 연결 · Chrome 프로필 여러 개) 하나가 닫혔다고 끊김으로 보지 않는다.
public struct ExtensionConnections: Equatable, Sendable {
    private struct Greeting: Equatable, Sendable {
        let id: Int
        let version: String
    }

    /// hello를 받은 순서대로
    private var greeted: [Greeting] = []
    private var open: Set<Int> = []
    public private(set) var everConnected = false

    public init() {}

    public mutating func opened(_ id: Int) {
        open.insert(id)
    }

    public mutating func hello(_ id: Int, version: String) {
        guard open.contains(id) else { return }
        greeted.removeAll { $0.id == id }
        greeted.append(Greeting(id: id, version: version))
        everConnected = true
    }

    public mutating func closed(_ id: Int) {
        open.remove(id)
        greeted.removeAll { $0.id == id }
    }

    /// 열려 있는 연결 중 가장 최근에 인사한 확장의 버전. 없으면 nil
    public var currentVersion: String? {
        greeted.last?.version
    }
}
