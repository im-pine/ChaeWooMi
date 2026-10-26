import SwiftUI

/// 메뉴바 메뉴 (APP-005): 플로팅 숨기기/보이기 · 런처 다시 표시
struct LauncherMenu: View {
    let launcher: FloatingController

    var body: some View {
        if launcher.failed {
            Text("플로팅 런처를 띄우지 못했습니다")
        }
        if launcher.hidden {
            Button("플로팅 보이기") { launcher.show() }
        } else {
            Button("플로팅 숨기기") { launcher.hide() }
            Button("런처 다시 표시") { launcher.show() }
        }
        Divider()
    }
}

/// 종료 메뉴. 앱은 사용자가 직접 켜므로 종료하면 다시 켤 때까지 꺼져 있다
struct QuitMenu: View {
    var body: some View {
        Button("채우미 종료") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
