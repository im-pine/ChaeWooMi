import Foundation

/// 호스트가 직접 주고받는 메시지 (앱을 거치지 않음)
public enum HostCommand {
    /// 확장 → 호스트: 확인창에서 "열기"를 고름 → 꺼진 앱을 실행한다. 앱에는 넘기지 않는다
    public static func isLaunchApp(_ message: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: message) as? [String: Any] else { return false }
        return object["type"] as? String == "launchApp"
    }

    /// 호스트 → 확장: 앱이 꺼져 있어 켜질 때까지 기다리는 중
    public static let appWaiting = Data(#"{"type":"appWaiting"}"#.utf8)
}

/// 호스트가 앱을 기다리는 동안 확장이 보낸 메시지를 모아 두었다가, 연결되면 받은 순서대로 넘긴다
public final class PendingLines: @unchecked Sendable {
    private let lock = NSLock()
    private var buffered: [Data] = []
    private var sink: (@Sendable (Data) -> Void)?

    public init() {}

    public func send(_ line: Data) {
        lock.lock()
        defer { lock.unlock() }
        if let sink { sink(line) } else { buffered.append(line) }
    }

    /// 모아 둔 메시지를 먼저 넘기고, 그다음부터는 바로 넘긴다
    public func attach(_ sink: @escaping @Sendable (Data) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        buffered.forEach(sink)
        buffered = []
        self.sink = sink
    }
}
