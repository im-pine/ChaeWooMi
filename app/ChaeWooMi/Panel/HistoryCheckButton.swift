import SwiftUI

/// "지원 이력 확인" 버튼 (Figma 이전 시안 `01 · Manual lookup`). 카드가 없거나 접혔을 때 화면 오른쪽 아래에 보인다.
/// 누르면 지금 보고 있는 공고를 다시 읽고, 지정 사이트 공고가 아니면 수동 조회 카드를 연다.
/// (AI 결정: 시안 오른쪽의 상세 아이콘은 카드가 없을 때 열 것이 없어 뺐다)
struct HistoryCheckButton: View {
    /// 확인 중이면 "확인 중…"
    var checking = false
    /// 지금 단계 · 알림 (`화면 다시 읽는 중`, `확장을 새로고침하세요` 등)
    var note: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CardTheme.primary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(CardTheme.primarySoft))
                VStack(alignment: .leading, spacing: 1) {
                    Text(checking ? "확인 중…" : "지원 이력 확인")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    if let note {
                        Text(note).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                .frame(maxWidth: 200, alignment: .leading)
            }
            .padding(.leading, 8)
            .padding(.trailing, 18)
            .frame(height: 52)
            .background(Capsule().fill(.background))
            .overlay(Capsule().stroke(CardTheme.border))
            .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
            .padding(6)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(checking)
        .help("지금 보고 있는 공고의 지원 이력을 확인합니다")
        .accessibilityLabel("지원 이력 확인")
    }
}
