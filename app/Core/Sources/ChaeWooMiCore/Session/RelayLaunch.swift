import Foundation

/// 중계 세션(`claude -p`) 실행 설정.
public struct RelayLaunch: Equatable, Sendable {
    public static let defaultSessionName = "chaewoomi-relay"
    /// 전달만 하므로 가벼운 모델 (기술 스택 2-2)
    public static let defaultModel = "haiku"

    public let executable: URL
    public let sessionName: String
    public let model: String
    /// 중계 세션 작업 폴더 (볼트가 아닌 앱 전용 폴더)
    public let workingDirectory: URL

    public init(
        executable: URL,
        workingDirectory: URL,
        sessionName: String = Self.defaultSessionName,
        model: String = Self.defaultModel
    ) {
        self.executable = executable
        self.workingDirectory = workingDirectory
        self.sessionName = sessionName
        self.model = model
    }

    public var arguments: [String] {
        [
            "-p",
            "--input-format", "stream-json",
            "--output-format", "stream-json",
            "--verbose",
            "--name", sessionName,
            "--model", model,
            // 다른 세션의 회신을 사람 승인 없이 받는다 (-p 세션은 승인 창을 띄울 수 없음)
            "--settings", #"{"crossSessionInbound":"accept"}"#,
            // 중계 세션은 파일을 바꾸지 않는다
            "--disallowedTools", "Edit,Write,NotebookEdit,Bash",
            "--append-system-prompt", Self.systemPrompt
        ]
    }

    /// 중계 규약. 2026-10-17 실측(요청 → 전달 3초 · 회신 8초, 글자 그대로 전달)한 문구다.
    public static let systemPrompt = """
    You are the ChaeWooMi relay. You only forward messages between the ChaeWooMi app and the user's \
    Claude Code role sessions. Never do any other work, never edit files, never rephrase.

    Input from the app is one JSON object per user turn:
    - {"op":"send","id":"<id>","to":"<session name>","text":"<text>"}: call SendMessage with `to` set to \
    exactly that session name and `message` set to `text` copied character for character. Then print exactly \
    one line: CHAEWOOMI {"event":"sent","id":"<id>"}. If SendMessage fails or the session is not found, print \
    CHAEWOOMI {"event":"not_sent","id":"<id>","reason":"<short reason>"}.
    - {"op":"list"}: call ListAgents, then print exactly one line: CHAEWOOMI {"event":"agents","names":["<name>",...]} \
    listing the names of the other local Claude Code sessions (not subagents, not yourself).

    When a message from another session arrives, print exactly one line and nothing else: \
    CHAEWOOMI {"event":"reply","from":"<sender session name>","text":"<full message text, JSON-escaped>"}.

    Every line you print must start with CHAEWOOMI followed by one space and one valid JSON object. Print nothing else.
    """

    /// GUI 앱은 셸 PATH를 물려받지 않으므로 흔한 설치 위치에서 `claude`를 찾는다.
    public static func findExecutable(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) -> URL? {
        let candidates = [
            home.appendingPathComponent(".local/bin/claude").path,
            home.appendingPathComponent(".claude/local/claude").path,
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude"
        ]
        return candidates.first(where: isExecutable).map { URL(fileURLWithPath: $0) }
    }
}
