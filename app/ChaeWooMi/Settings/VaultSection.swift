import SwiftUI

/// 설정: 볼트 경로 지정과 12.0 읽기 점검 결과.
struct VaultSection: View {
    @Bindable var settings: AppSettings
    @State private var choosing = false

    var body: some View {
        Section("볼트") {
            LabeledContent("경로") {
                Text(settings.vaultPath ?? "지정 안 됨")
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Button("볼트 폴더 선택…") { choosing = true }
            checkResult
        }
        .fileImporter(isPresented: $choosing, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { settings.vaultPath = url.path }
        }
    }

    private var checkResult: some View {
        let check = VaultCheck.message(for: settings.vaultPath)
        return Label(check.text, systemImage: check.ok ? "checkmark.circle" : "exclamationmark.triangle")
            .foregroundStyle(check.ok ? Color.secondary : Color.orange)
    }
}
