// Chrome Native Messaging 호스트. Chrome이 확장 연결 시 실행한다.
// Chrome(표준 입출력, 4바이트 길이 + JSON) ↔ 채우미 앱(소켓, JSON 한 줄)을 내용 해석 없이 이어 준다.
// 앱이 꺼져 있으면 실행하지 않고 켜질 때까지 기다린다 (확장에 appWaiting을 알림). 그동안 받은 메시지는 연결 뒤 순서대로 넘긴다.
// 확장이 launchApp(공고 페이지 확인창의 "열기")을 보낼 때만 앱을 실행한다.
import ChaeWooMiCore
import Foundation

let socketPath = BridgePaths.socket().path
let toApp = PendingLines()

@Sendable func toChrome(_ message: Data) {
    if let framed = try? NativeMessageFraming.frame(message) {
        FileHandle.standardOutput.write(framed)
    }
}

// Chrome → 앱. Chrome이 표준 입력을 닫으면(확장 연결 끊김) 끝낸다 — 앱을 기다리는 중이어도
Thread.detachNewThread {
    while let message = NativeMessageFraming.readMessage(from: .standardInput) {
        if HostCommand.isLaunchApp(message) { HostLauncher.openApp() } else { toApp.send(message) }
    }
    exit(0)
}

let app = await HostLauncher.waitForApp(socketPath: socketPath) { toChrome(HostCommand.appWaiting) }
toApp.attach { line in try? app.send(line: line) }

// 앱 → Chrome. 앱이 연결을 닫으면 호스트도 끝난다
for await line in app.lines {
    toChrome(Data(line.utf8))
}
exit(0)
