import Foundation

/// 중계 세션 프로세스를 띄우고 요청 · 사건을 주고받는다.
///
/// 채우미는 분석 · 작성을 직접 하지 않고 요청만 보낸다. 결과의 최종 판정은 볼트 파일로 한다 (회신은 보조 신호).
public actor RelayClient {
    public enum RelayError: Error, Equatable {
        case launchFailed(String)
        case notRunning
        case timedOut
        /// 중계 세션이 보내지 못했다고 알림 (세션 없음 등)
        case notSent(reason: String)
    }

    public struct Reply: Equatable, Sendable {
        public let from: String
        public let text: String
    }

    /// 역할 세션이 보낸 회신
    public nonisolated let replies: AsyncStream<Reply>
    private let replyContinuation: AsyncStream<Reply>.Continuation

    private let launch: RelayLaunch
    private var process: Process?
    private var input: FileHandle?
    private var pendingSends: [String: CheckedContinuation<Result<Void, RelayError>, Never>] = [:]
    /// 목록 요청은 보낸 순서대로 답이 오므로 순서를 지킨다
    private var pendingLists: [(key: UUID, continuation: CheckedContinuation<Result<[String], RelayError>, Never>)] = []

    public init(launch: RelayLaunch) {
        self.launch = launch
        (replies, replyContinuation) = AsyncStream.makeStream()
    }

    public var isRunning: Bool { process?.isRunning ?? false }

    public func start() throws(RelayError) {
        guard !isRunning else { return }
        let process = Process()
        process.executableURL = launch.executable
        process.arguments = launch.arguments
        process.currentDirectoryURL = launch.workingDirectory
        let stdin = Pipe()
        let stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] _ in
            Task { await self?.processEnded() }
        }
        do {
            try process.run()
        } catch {
            throw .launchFailed(error.localizedDescription)
        }
        self.process = process
        input = stdin.fileHandleForWriting
        readOutput(stdout.fileHandleForReading)
    }

    public func stop() {
        process?.terminate()
        processEnded()
    }

    /// `to` 세션에 `text`를 그대로 보낸다. 중계 세션이 보냈다고 알리면 돌아온다.
    public func send(
        id: String,
        to session: String,
        text: String,
        timeout: Duration = .seconds(60)
    ) async throws(RelayError) {
        try write(.send(id: id, session: session, text: text))
        let result = await withCheckedContinuation { continuation in
            pendingSends[id] = continuation
            scheduleTimeout(after: timeout) { client in await client.finishSend(id: id, .failure(.timedOut)) }
        }
        try result.get()
    }

    /// 같은 Mac에서 메시지를 받을 수 있는 세션 이름 목록
    public func listSessions(timeout: Duration = .seconds(60)) async throws(RelayError) -> [String] {
        try write(.list)
        let key = UUID()
        let result = await withCheckedContinuation { continuation in
            pendingLists.append((key, continuation))
            scheduleTimeout(after: timeout) { client in await client.finishList(key: key, .failure(.timedOut)) }
        }
        return try result.get()
    }

    private func write(_ request: RelayRequest) throws(RelayError) {
        guard isRunning, let input else { throw .notRunning }
        do {
            try input.write(contentsOf: Data(request.inputLine().utf8))
        } catch {
            throw .notRunning
        }
    }

    private func readOutput(_ handle: FileHandle) {
        // 출력이 끊기면 프로세스 종료 처리에서 대기 중인 요청을 실패로 돌린다
        let lines = LineReader.lines(from: handle)
        Task { [weak self] in
            for await line in lines {
                for event in RelayOutputParser.events(fromStreamLine: line) {
                    await self?.handle(event)
                }
            }
        }
    }

    private func handle(_ event: RelayEvent) {
        switch event {
        case let .sent(id):
            finishSend(id: id, .success(()))
        case let .notSent(id, reason):
            finishSend(id: id, .failure(.notSent(reason: reason)))
        case let .agents(names):
            if let key = pendingLists.first?.key { finishList(key: key, .success(names)) }
        case let .reply(from, text):
            replyContinuation.yield(Reply(from: from, text: text))
        }
    }

    private func finishSend(id: String, _ result: Result<Void, RelayError>) {
        pendingSends.removeValue(forKey: id)?.resume(returning: result)
    }

    private func finishList(key: UUID, _ result: Result<[String], RelayError>) {
        guard let index = pendingLists.firstIndex(where: { $0.key == key }) else { return }
        pendingLists.remove(at: index).continuation.resume(returning: result)
    }

    private func scheduleTimeout(after timeout: Duration, _ action: @escaping @Sendable (RelayClient) async -> Void) {
        Task { [weak self] in
            try? await Task.sleep(for: timeout)
            if let self { await action(self) }
        }
    }

    private func processEnded() {
        process = nil
        input = nil
        for id in pendingSends.keys { finishSend(id: id, .failure(.notRunning)) }
        for key in pendingLists.map(\.key) { finishList(key: key, .failure(.notRunning)) }
    }
}
