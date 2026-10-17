import ChaeWooMiCore
import SwiftUI

/// 플로팅 패널 내용: 런처 또는 카드 (APP-002 · APP-011). 크기는 사이트와 무관하게 앱 기준 (APP-015)
struct FloatingRoot: View {
    let store: CardStore

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            // 지원 완료 화면은 공고 페이지가 아니어도 뜬다 (HIS-017)
            if let records = store.records, records.presenting {
                ApplyCompleteCard(records: records)
            }
            if store.showsLauncherOnly {
                Button { store.collapsed = false } label: { LauncherView() }
                    .buttonStyle(.plain)
            } else {
                card
            }
        }
        .fixedSize()
    }

    @ViewBuilder private var card: some View {
        switch store.content {
        case let .company(name, lookup):
            CompanyCard(store: store, company: name, lookup: lookup, source: source)
        case let .manual(lookup):
            ManualCard(store: store, lookup: lookup)
        case let .choosing(choice):
            ChooserCard(store: store, choice: choice)
        case .hidden:
            LauncherView()
        }
    }

    /// `원티드 · 공고 제목` (설정 라벨)
    private var source: String? {
        guard let page = store.model.page else { return nil }
        let label = SiteConfig.defaultConfig.sites.first { $0.id == page.site }?.label ?? page.site
        return [label, page.title].compactMap { $0 }.joined(separator: " · ")
    }
}
