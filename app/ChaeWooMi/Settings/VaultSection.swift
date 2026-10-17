import SwiftUI

/// 설정: 볼트 경로 지정과 12.0 읽기 점검 결과.
struct VaultSection: View {
    @Bindable var settings: AppSettings
    @State private var choosing = false
    @State private var check = VaultCheck.checking

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
        // 경로가 바뀔 때만 점검한다 (화면을 다시 그릴 때마다 볼트를 훑지 않음)
        .task(id: settings.vaultPath) {
            check = .checking
            let path = settings.vaultPath
            check = await Task.detached { VaultCheck.run(for: path) }.value
        }
    }

    private var checkResult: some View {
        Label(check.text, systemImage: check.isOK ? "checkmark.circle" : "exclamationmark.triangle")
            .foregroundStyle(check.isOK ? Color.secondary : Color.orange)
    }
}
