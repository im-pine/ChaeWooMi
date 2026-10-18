import ChaeWooMiCore
import SwiftUI

/// 설정: 볼트 경로 · 12.0 읽기 · 세션 연결 · 브라우저 연결을 한 번에 점검한다 (SET-006)
struct CheckSection: View {
    let settings: AppSettings
    let sessions: SessionHub
    let bridge: BrowserBridge
    @State private var items: [SettingsCheckItem] = []
    @State private var running = false

    var body: some View {
        Section("설정 점검") {
            ForEach(items, id: \.kind) { item in
                CheckRow(item: item)
            }
            Button(running ? "점검 중…" : "설정 점검") {
                Task { await run() }
            }
            .disabled(running)
        }
    }

    private func run() async {
        running = true
        defer { running = false }
        let paths = settings.vaultPaths
        let vault = await Task.detached { Self.vaultItems(paths: paths) }.value
        await sessions.refresh()
        bridge.installHostManifest()
        let session = SettingsCheck.sessionItem(
            roster: settings.sessionRoster,
            listed: sessions.listed,
            error: sessions.lastError
        )
        items = vault + [session, SettingsCheck.browserItem(bridge.status)]
    }

    private nonisolated static func vaultItems(paths: VaultPaths) -> [SettingsCheckItem] {
        SettingsCheck.vaultItems(paths: paths)
    }
}

/// 점검 항목 한 줄. 실패한 항목만 해결 방법을 펼쳐 보인다
private struct CheckRow: View {
    let item: SettingsCheckItem

    var body: some View {
        switch item.outcome {
        case let .passed(detail):
            LabeledContent(item.kind.label) { Label(detail, systemImage: "checkmark.circle").lineLimit(1) }
        case let .failed(reason):
            VStack(alignment: .leading, spacing: 2) {
                Label(item.kind.label, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                Text(reason).font(.caption)
            }
        case let .skipped(reason):
            LabeledContent(item.kind.label) { Text(reason).foregroundStyle(.secondary) }
        }
    }
}
