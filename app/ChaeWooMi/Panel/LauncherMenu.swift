import SwiftUI

/// 메뉴바: 런처 다시 표시 (런처를 띄우지 못했으면 안내 문구와 함께)
struct LauncherMenu: View {
    let launcher: FloatingController

    var body: some View {
        if launcher.failed {
            Text("플로팅 런처를 띄우지 못했습니다")
        }
        Button("런처 다시 표시") { launcher.show() }
        Divider()
    }
}
