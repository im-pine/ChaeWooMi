import ChaeWooMiCore
import SwiftUI

/// 설정: 역할 세션 3종의 이름과 연결 상태 (AGT-001 · SET-003 · AGT-004)
struct SessionSection: View {
    @Bindable var settings: AppSettings
    let sessions: SessionHub

    var body: some View {
        Section("Claude Code 세션") {
            ForEach(SessionRole.allCases, id: \.self) { role in
                row(for: role)
            }
            ForEach(problemTexts, id: \.self) { text in
                Label(text, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            }
            if let error = sessions.lastError {
                Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            }
            Button(sessions.checking ? "확인 중…" : "연결 확인") {
                Task { await sessions.refresh() }
            }
            .disabled(sessions.checking)
        }
    }

    private func row(for role: SessionRole) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(role.label, text: nameBinding(for: role), prompt: Text(role.defaultSessionName))
            if let availability = sessions.availability(of: role, roster: settings.sessionRoster) {
                Text(availability.guidance(for: role))
                    .font(.caption)
                    .foregroundStyle(availability.isConnected ? Color.secondary : Color.orange)
            }
        }
    }

    private func nameBinding(for role: SessionRole) -> Binding<String> {
        Binding(
            get: { settings.sessionRoster.names[role] ?? "" },
            set: { settings.sessionRoster.set($0, for: role) }
        )
    }

    private var problemTexts: [String] {
        settings.sessionRoster.problems.compactMap { problem in
            guard case let .duplicated(name, roles) = problem else { return nil }
            return "`\(name)` 세션을 \(roles.map(\.label).joined(separator: " · "))가 함께 씁니다. 역할마다 다른 세션을 지정하세요"
        }
    }
}
