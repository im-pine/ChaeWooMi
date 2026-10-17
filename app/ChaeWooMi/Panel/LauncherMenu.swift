import SwiftUI

/// 메뉴바 메뉴 (APP-005): 자동 실행 스위치 · 플로팅 숨기기/보이기 · 런처 다시 표시. 종료와 자동 실행 끄기를 구분한다
struct LauncherMenu: View {
    @Bindable var settings: AppSettings
    let launcher: FloatingController

    var body: some View {
        if launcher.failed {
            Text("플로팅 런처를 띄우지 못했습니다")
        }
        Toggle("공고 페이지에서 자동 실행", isOn: $settings.autoLaunchFromBrowser)
        if launcher.hidden {
            Button("플로팅 보이기") { launcher.show() }
        } else {
            Button("플로팅 숨기기") { launcher.hide() }
            Button("런처 다시 표시") { launcher.show() }
        }
        Divider()
    }
}

/// 종료 메뉴: 자동 실행이 켜져 있으면 다음 공고에서 다시 켜진다고 알린다
struct QuitMenu: View {
    let settings: AppSettings

    var body: some View {
        if settings.autoLaunchFromBrowser {
            Text("종료해도 다음 공고에서 다시 켜집니다")
        }
        Button("채우미 종료") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
