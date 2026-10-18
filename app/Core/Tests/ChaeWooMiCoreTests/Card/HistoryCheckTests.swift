import Testing
@testable import ChaeWooMiCore

@Suite("지원 이력 확인 버튼 단계 (직접 입력은 최후의 수단)")
struct HistoryCheckTests {
    @Test("다시 읽기 → (못 찾으면) 새로고침 → (그래도 없으면) 직접 입력")
    func escalates() {
        var check = HistoryCheck()
        #expect(check.start(extensionVersion: "0.2.0") == [.rescan(reload: false)])
        #expect(check.label == "화면 다시 읽는 중")
        #expect(check.timedOut() == [.rescan(reload: true)])
        #expect(check.label == "페이지 새로고침 중")
        #expect(check.timedOut() == [.manual(reason: "이 페이지에서 회사명을 찾지 못해 직접 입력합니다")])
        #expect(!check.isChecking)
    }

    @Test("공고가 오면 그 자리에서 끝나고 직접 입력으로 가지 않는다")
    func stopsWhenFound() {
        var check = HistoryCheck()
        _ = check.start(extensionVersion: "0.2.0")
        check.found()
        #expect(check.timedOut().isEmpty)
        #expect(!check.isChecking)
    }

    @Test("연결이 없으면 바로 직접 입력이 아니라 연결을 기다리고, 이어지면 다시 읽는다 (사용자 보고)")
    func waitsForConnection() {
        var check = HistoryCheck()
        #expect(check.start(extensionVersion: nil).isEmpty)
        #expect(check.step == .waitingConnection)
        #expect(check.connected(extensionVersion: "0.2.0") == [.rescan(reload: false)])
        var never = HistoryCheck()
        _ = never.start(extensionVersion: nil)
        #expect(never.timedOut() == [.manual(reason: "브라우저 확장과 연결되지 않아 회사명을 직접 입력합니다")])
    }

    @Test("지정 사이트 공고가 아니라는 알림이면 새로고침 · 기다림 없이 바로 직접 입력")
    func notPostingSkips() {
        var check = HistoryCheck()
        _ = check.start(extensionVersion: "0.2.0")
        #expect(check.notPosting() == [.manual(reason: "지정 사이트 공고 페이지가 아니라 회사명을 직접 입력합니다")])
        #expect(!check.isChecking)
        var idle = HistoryCheck()
        #expect(idle.notPosting().isEmpty)
    }

    @Test("예전 확장(다시 읽기를 모름)이면 직접 입력 대신 확장 새로고침을 알린다")
    func oldExtension() {
        var check = HistoryCheck()
        #expect(check.start(extensionVersion: "0.1.0") == [
            .notice("채우미 확장을 새로고침(↻)하세요 — 예전 확장은 화면을 다시 읽지 못합니다")
        ])
        #expect(!check.isChecking)
    }

    @Test("확인 중에 다시 눌러도 처음부터 하지 않는다")
    func ignoresDoubleTap() {
        var check = HistoryCheck()
        _ = check.start(extensionVersion: "0.2.0")
        #expect(check.start(extensionVersion: "0.2.0").isEmpty)
        #expect(check.step == .rescanning)
    }

    @Test("버전 비교는 숫자로", arguments: [
        ("0.2.0", true), ("0.10.0", true), ("1.0", true), ("0.1.9", false), ("0.2", true)
    ])
    func version(version: String, atLeast: Bool) {
        #expect(HistoryCheck.isAtLeast(version, "0.2.0") == atLeast)
    }
}
