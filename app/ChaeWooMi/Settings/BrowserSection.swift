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
            if !bridge.siteConfig.problems.isEmpty {
                // sites.json이 틀리면 기본 설정으로 동작한다. 왜 수정이 반영되지 않는지 보인다
                Label("sites.json을 쓰지 못해 기본 사이트 설정으로 동작합니다", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                ForEach(bridge.siteConfig.problems, id: \.self) { Text($0).font(.caption) }
            }
            Button("연결 다시 등록") { bridge.installHostManifest() }
        }
    }
}
