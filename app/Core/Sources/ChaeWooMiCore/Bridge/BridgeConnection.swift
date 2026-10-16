import Foundation

/// 소켓 연결 하나. 메시지는 JSON 한 줄씩 주고받는다.
public final class BridgeConnection: Sendable {
    /// 읽기 · 쓰기를 다른 핸들로 둔다. 같은 FileHandle로 읽는 중에 쓰면 쓰기가 막힌다
    private let reader: FileHandle
    private let writer: FileHandle

    /// 받은 줄. 상대가 닫으면 끝난다. 한 곳에서만 읽는다
    public let lines: AsyncStream<String>

    init(descriptor: Int32) {
        reader = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        writer = FileHandle(fileDescriptor: dup(descriptor), closeOnDealloc: true)
        lines = LineReader.lines(from: reader)
    }

    /// 실행 중인 앱의 소켓에 연결한다
    public static func connect(path: String) throws(UnixSocketError) -> BridgeConnection {
        BridgeConnection(descriptor: try UnixSocket.connect(path: path))
    }

    /// JSON 한 줄을 그대로 보낸다 (줄바꿈이 들어 있으면 보내지 않음)
    public func send(line: Data) throws {
        guard !line.contains(UInt8(ascii: "\n")) else { return }
        try writer.write(contentsOf: line + Data("\n".utf8))
    }

    public func send<Message: Encodable>(_ message: Message) throws {
        try send(line: try JSONEncoder().encode(message))
    }

    public func close() {
        // 읽기 쪽까지 끝나도록 소켓을 양방향으로 닫는다
        shutdown(writer.fileDescriptor, SHUT_RDWR)
        try? writer.close()
    }
}

/// 앱이 여는 소켓 서버. 호스트(Chrome이 실행)가 여기에 접속한다.
public final class BridgeServer: Sendable {
    public let path: String
    private let descriptor: Int32

    public init(path: String) throws(UnixSocketError) {
        self.path = path
        descriptor = try UnixSocket.listen(path: path)
    }

    /// 접속을 받을 때마다 `onConnection`을 부른다. `stop()` 전까지 백그라운드 스레드에서 돈다.
    public func start(onConnection: @escaping @Sendable (BridgeConnection) -> Void) {
        let descriptor = descriptor
        Thread.detachNewThread {
            while true {
                let client = accept(descriptor, nil, nil)
                guard client >= 0 else { return }
                onConnection(BridgeConnection(descriptor: client))
            }
        }
    }

    public func stop() {
        Darwin.shutdown(descriptor, SHUT_RDWR)
        Darwin.close(descriptor)
        unlink(path)
    }
}
