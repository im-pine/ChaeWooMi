import SwiftUI

/// 설정 창: 볼트 경로 · 세션 연결 · 브라우저 연결 · 점검
struct SettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            VaultSection(settings: settings)
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }
}
