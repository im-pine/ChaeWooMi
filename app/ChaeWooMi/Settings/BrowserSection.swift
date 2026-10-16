import ChaeWooMiCore
import SwiftUI

/// 설정: 브라우저(Chrome 확장) 연결 상태와 해결 방법 (SET-005)
struct BrowserSection: View {
    let bridge: BrowserBridge

    var body: some View {
        Section("브라우저 연결") {
            let status = bridge.status
            Label(status.guidance, systemImage: status.isProblem ? "exclamationmark.triangle" : "checkmark.circle")
                .foregroundStyle(status.isProblem ? Color.orange : Color.secondary)
            if let error = bridge.serverError {
                Text(error).foregroundStyle(.red)
            }
            Button("연결 다시 등록") { bridge.installHostManifest() }
        }
    }
}
