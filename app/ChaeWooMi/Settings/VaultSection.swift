import ChaeWooMiCore
import SwiftUI
import UniformTypeIdentifiers

/// 설정: 항목별 저장 위치와 이름 규칙 (2026-10-18). 세션에 보내는 요청의 `저장 경로`도 이 규칙으로 정한다
struct VaultSection: View {
    @Bindable var settings: AppSettings
    @State private var choosing: Item?
    @State private var check = VaultCheck.checking

    enum Item: Identifiable {
        case statusFile, postingFolder, outputFolder
        var id: Self { self }
    }

    var body: some View {
        Section("저장 위치") {
            pathRow("지원 현황", settings.vaultPaths.statusFile, item: .statusFile)
            pathRow("공고 분석", settings.vaultPaths.postingFolder, item: .postingFolder)
            Text("`{기업명}/공고.md` — 기업명은 (주) 같은 표기를 뺀 이름").font(.caption).foregroundStyle(.secondary)
            pathRow("이력서 · 자기소개서", settings.vaultPaths.outputFolder, item: .outputFolder)
            Text("`{기업명} {연도}/{이름}_이력서_{기업명}.md` · `_자기소개서_` · 같은 이름 `.pdf`")
                .font(.caption).foregroundStyle(.secondary)
            TextField("이름", text: $settings.vaultPaths.ownerName, prompt: Text("파일 이름 앞부분"))
            checkResult
        }
        .fileImporter(isPresented: Binding(get: { choosing != nil }, set: { if !$0 { choosing = nil } }),
                      allowedContentTypes: choosing == .statusFile ? [.plainText, .data] : [.folder]) { result in
            guard case let .success(url) = result, let item = choosing else { return }
            switch item {
            case .statusFile: settings.vaultPaths.statusFile = url.path
            case .postingFolder: settings.vaultPaths.postingFolder = url.path
            case .outputFolder: settings.vaultPaths.outputFolder = url.path
            }
        }
        // 위치가 바뀔 때만 점검한다 (화면을 다시 그릴 때마다 12.0을 읽지 않음)
        .task(id: settings.vaultPaths) {
            check = .checking
            let paths = settings.vaultPaths
            check = await Task.detached { VaultCheck.run(for: paths) }.value
        }
    }

    private func pathRow(_ title: String, _ path: String, item: Item) -> some View {
        LabeledContent(title) {
            HStack {
                Text(path.isEmpty ? "지정 안 됨" : path)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .help(path)
                Button("선택…") { choosing = item }
            }
        }
    }

    private var checkResult: some View {
        Label(check.text, systemImage: check.isOK ? "checkmark.circle" : "exclamationmark.triangle")
            .foregroundStyle(check.isOK ? Color.secondary : Color.orange)
    }
}
