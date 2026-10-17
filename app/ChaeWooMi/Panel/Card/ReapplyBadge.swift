import ChaeWooMiCore
import SwiftUI

/// 재지원 판별 줄 (APP-008 · MAT-013). 라벨 없음은 아무것도 그리지 않고, 조회 불가는 반드시 구분해 보인다
struct ReapplyBadge: View {
    let lookup: CompanyLookup
    var onRetry: () -> Void = {}

    var body: some View {
        switch lookup {
        case let .caution(_, info):
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Label("재지원 주의", systemImage: "exclamationmark.circle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(CardTheme.caution)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(CardTheme.cautionSoft))
                    Text("\(ReapplyInfo.display(info.lastSubmitted)) 지원").font(.system(size: 10, weight: .medium))
                }
                Text("\(ReapplyInfo.display(info.reapplyFrom))부터 재지원 가능")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        case let .unavailable(failure):
            HStack(spacing: 6) {
                Label("조회 불가", systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 10, weight: .semibold))
                Button("다시 시도", action: onRetry).font(.system(size: 10)).buttonStyle(.link)
            }
            .help("\(failure.reason). \(failure.fix)")
        case .clear, .needsChoice, .needsName:
            EmptyView()
        }
    }
}
