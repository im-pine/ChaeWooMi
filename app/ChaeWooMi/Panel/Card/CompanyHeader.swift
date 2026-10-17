import SwiftUI

/// 카드 머리: 회사 첫 글자 · 회사명 · 출처(사이트) · 펼치기
struct CompanyHeader: View {
    let company: String
    let source: String?
    @Binding var expanded: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(String(company.first ?? "?"))
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 24, height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(CardTheme.primarySoft))
            VStack(alignment: .leading, spacing: 1) {
                Text(company).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                if let source {
                    Text(source).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Button { expanded.toggle() } label: {
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(expanded ? "상세 접기" : "상세보기")
            .accessibilityLabel(expanded ? "상세 접기" : "상세보기")
        }
    }
}
