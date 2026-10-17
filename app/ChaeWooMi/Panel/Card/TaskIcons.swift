import ChaeWooMiCore
import SwiftUI

/// 분석 · 이력서 · 자소서 아이콘 3종 (APP-012 · APP-013 · APP-017). 아이콘 안 글자 없이 툴팁으로 이름 · 상태
struct TaskIcons: View {
    let state: (TaskKind) -> TaskState
    let onAction: (TaskKind, TaskAction) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TaskKind.allCases, id: \.self) { kind in
                let current = state(kind)
                Button { onAction(kind, TaskAction.onClick(current)) } label: {
                    TaskIcon(kind: kind, state: current)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .help("\(kind.label) · \(current.label)")
                .accessibilityLabel("\(kind.label), \(current.label)")
            }
        }
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
    }
}

private struct TaskIcon: View {
    let kind: TaskKind
    let state: TaskState

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 14))
            .foregroundStyle(isUnavailable ? Color.secondary.opacity(0.5) : Color.primary)
            .frame(width: 28, height: 22)
            .overlay(alignment: .topTrailing) { badge }
    }

    private var symbol: String {
        switch kind {
        case .analysis: "doc.text.magnifyingglass"
        case .resume: "doc.richtext"
        case .coverLetter: "envelope"
        }
    }

    private var isUnavailable: Bool {
        if case .unavailable = state { return true }
        return false
    }

    @ViewBuilder private var badge: some View {
        switch state {
        case .completed:
            Image(systemName: "checkmark.circle.fill").font(.system(size: 9)).foregroundStyle(CardTheme.primary)
        case .waitingReview: Circle().fill(CardTheme.pending).frame(width: 6, height: 6)
        case .running: ProgressView().controlSize(.mini)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill").font(.system(size: 9)).foregroundStyle(CardTheme.caution)
        case .ready, .unavailable: EmptyView()
        }
    }
}
