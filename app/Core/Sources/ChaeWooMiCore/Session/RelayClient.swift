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
        /// 같은 id의 요청이 아직 진행 중
        case duplicateID
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
    private var pendingLists: [String: CheckedContinuation<Result<[String], RelayError>, Never>] = [:]

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
        process.terminationHandler = { [weak self] ended in
            // 다시 띄운 뒤 이전 프로세스의 종료가 늦게 와도 새 프로세스를 지우지 않게 누가 끝났는지 넘긴다
            let ended = ObjectIdentifier(ended)
            Task { await self?.processEnded(ended) }
        }
        do {
            try process.run()
        } catch {
            throw .launchFailed(error.localizedDescription)
        }
        // 중계 세션이 먼저 끝나 읽는 쪽이 닫혀도 SIGPIPE로 앱이 죽지 않고 쓰기 오류가 되게 한다
        _ = fcntl(stdin.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
        self.process = process
        input = stdin.fileHandleForWriting
        readOutput(stdout.fileHandleForReading)
    }

    public func stop() {
        guard let process else { return }
        process.terminate()
        processEnded(ObjectIdentifier(process))
    }

    /// `to` 세션에 `text`를 그대로 보낸다. 중계 세션이 보냈다고 알리면 돌아온다.
    public func send(
        id: String,
        to session: String,
        text: String,
        timeout: Duration = .seconds(60)
    ) async throws(RelayError) {
        guard pendingSends[id] == nil else { throw .duplicateID }
        try write(.send(id: id, session: session, text: text))
        let result = await withCheckedContinuation { continuation in
            pendingSends[id] = continuation
            scheduleTimeout(after: timeout) { client in await client.finishSend(id: id, .failure(.timedOut)) }
        }
        try result.get()
    }

    /// 같은 Mac에서 메시지를 받을 수 있는 세션 이름 목록. 응답이 없으면 다시 묻는다 (목록 조회는 여러 번 해도 같음).
    /// 실측: 역할 세션 회신이 막 도착한 순간 목록을 물으면, 중계 모델이 회신 한 줄만 출력하고 목록 응답을 빠뜨렸다 →
    /// 앱이 60초 기다리다 "중계 세션이 응답하지 않습니다"로 이력서 요청을 취소함
    public func listSessions(timeout: Duration = .seconds(15), attempts: Int = 3) async throws(RelayError) -> [String] {
        for attempt in 1...max(attempts, 1) {
            do {
                return try await listOnce(timeout: timeout)
            } catch {
                guard error == .timedOut, attempt < attempts else { throw error }
            }
        }
        throw .timedOut
    }

    private func listOnce(timeout: Duration) async throws(RelayError) -> [String] {
        let id = UUID().uuidString
        try write(.list(id: id))
        let result = await withCheckedContinuation { continuation in
            pendingLists[id] = continuation
            scheduleTimeout(after: timeout) { client in await client.finishList(id: id, .failure(.timedOut)) }
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
        case let .agents(id, names):
            // 시간 초과로 끝난 요청의 늦은 응답은 id가 없어 버려진다
            finishList(id: id, .success(names))
        case let .reply(from, text):
            replyContinuation.yield(Reply(from: from, text: text))
        }
    }

    private func finishSend(id: String, _ result: Result<Void, RelayError>) {
        pendingSends.removeValue(forKey: id)?.resume(returning: result)
    }

    private func finishList(id: String, _ result: Result<[String], RelayError>) {
        pendingLists.removeValue(forKey: id)?.resume(returning: result)
    }

    private func scheduleTimeout(after timeout: Duration, _ action: @escaping @Sendable (RelayClient) async -> Void) {
        Task { [weak self] in
            try? await Task.sleep(for: timeout)
            if let self { await action(self) }
        }
    }

    private func processEnded(_ ended: ObjectIdentifier) {
        guard let process, ObjectIdentifier(process) == ended else { return }
        self.process = nil
        input = nil
        for id in pendingSends.keys { finishSend(id: id, .failure(.notRunning)) }
        for id in pendingLists.keys { finishList(id: id, .failure(.notRunning)) }
    }
}
