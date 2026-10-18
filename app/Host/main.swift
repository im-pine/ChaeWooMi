// Chrome Native Messaging 호스트. Chrome이 확장 연결 시 실행한다.
// Chrome(표준 입출력, 4바이트 길이 + JSON) ↔ 채우미 앱(소켓, JSON 한 줄)을 내용 해석 없이 이어 준다.
// 앱이 꺼져 있으면 실행하고 소켓이 열릴 때까지 기다린다. 메뉴바 자동 실행 스위치가 꺼져 있거나,
// 확장이 스스로 다시 연결한 것(첫 인사에 quiet)이면 실행하지 않는다.
import ChaeWooMiCore
import Foundation

let socketPath = BridgePaths.socket().path
// 첫 메시지(인사)를 먼저 읽어 조용한 재연결인지 본다. 읽은 메시지는 연결 뒤 그대로 앱에 넘긴다
let firstMessage = NativeMessageFraming.readMessage(from: .standardInput)
let quiet = firstMessage.map(HostLaunchHint.isQuiet) ?? false
let mayLaunch = !quiet && AutoLaunchPolicy.isEnabled(AutoLaunchPolicy.appDefaults())
let app: BridgeConnection? = if mayLaunch {
    // 연결 함수는 메인 액터 밖에서 클로저를 부른다 → 액터에 속하지 않는 클로저로 (Swift 6 실행 중 경고)
    await HostLauncher.connect(socketPath: socketPath, launchApp: { @Sendable in HostLauncher.openApp() })
} else {
    try? BridgeConnection.connect(path: socketPath)
}
guard let app else { exit(1) }
if let firstMessage { try? app.send(line: firstMessage) }

// Chrome → 앱. Chrome이 표준 입력을 닫으면(확장 연결 끊김) 끝낸다
Thread.detachNewThread {
    while let message = NativeMessageFraming.readMessage(from: .standardInput) {
        try? app.send(line: message)
    }
    app.close()
    exit(0)
}

// 앱 → Chrome. 앱이 연결을 닫으면 호스트도 끝난다
for await line in app.lines {
    if let framed = try? NativeMessageFraming.frame(Data(line.utf8)) {
        FileHandle.standardOutput.write(framed)
    }
}
exit(0)
