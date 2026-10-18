import ChaeWooMiCore
import SwiftUI

/// 수동 카드 (WEB-007 · WEB-008 · APP-018): 회사명 직접 입력 → 조회. 공고 원문이 없어 아이콘은 두지 않는다
struct ManualCard: View {
    let store: CardStore
    let lookup: CompanyLookup?
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("회사 확인", systemImage: "magnifyingglass").font(.system(size: 12, weight: .semibold))
                Spacer()
                Button { store.handle(.dismissed) } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .help("닫기")
            }
            // 다시 읽기 · 새로고침으로도 회사명을 못 찾았을 때 그 이유
            if let notice = store.notice {
                Text(notice).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            TextField("회사명", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)
            HStack {
                Spacer()
                Button("조회", action: submit)
                    .disabled(!CompanyName(name).isUsable)
            }
            if let lookup { result(lookup) }
        }
        .frame(width: CardTheme.manualWidth - 20, alignment: .leading)
        .cardBackground()
    }

    private func submit() {
        store.handle(.nameEntered(name))
    }

    @ViewBuilder private func result(_ lookup: CompanyLookup) -> some View {
        switch lookup {
        case let .clear(company, _):
            Text("\(company) · 1년 내 지원 기록 없음").font(.system(size: 10)).foregroundStyle(.secondary)
        default:
            ReapplyBadge(lookup: lookup)
        }
    }
}

/// 회사 선택 모달 (MAT-005): 후보 + `새 회사로 추가`. 임의로 확정하지 않는다
struct ChooserCard: View {
    let store: CardStore
    let choice: CompanyMatcher.Choice
    @State private var selected: String?
    @State private var newName = ""
    @State private var addingNew = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("어느 회사인가요?").font(.system(size: 14, weight: .semibold))
            Text(choice.extracted.joined(separator: " · ")).font(.system(size: 11)).foregroundStyle(.secondary)
            ForEach(choice.existing, id: \.self) { company in candidate(company) }
            newCompany
            HStack {
                Spacer()
                Button("취소") { store.handle(.dismissed) }
                Button("선택", action: confirm).buttonStyle(.borderedProminent).tint(CardTheme.primary)
                    .disabled(chosenName == nil)
            }
        }
        .frame(width: CardTheme.chooserWidth - 20, alignment: .leading)
        .cardBackground()
        .onAppear { newName = choice.extracted.first ?? "" }
    }

    private var chosenName: String? {
        addingNew ? (CompanyName(newName).isUsable ? newName : nil) : selected
    }

    private func confirm() {
        if let chosenName { store.handle(.chosen(chosenName)) }
    }

    private func candidate(_ company: String) -> some View {
        Button {
            selected = company
            addingNew = false
        } label: {
            HStack {
                Image(systemName: selected == company && !addingNew ? "largecircle.fill.circle" : "circle")
                VStack(alignment: .leading) {
                    Text(company).font(.system(size: 12, weight: .medium))
                    if let day = store.latestSubmitted(company) {
                        Text("최근 지원 \(ReapplyInfo.display(day))").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var newCompany: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { addingNew = true } label: {
                Label("새 회사로 추가", systemImage: addingNew ? "largecircle.fill.circle" : "plus")
            }
            .buttonStyle(.plain)
            if addingNew {
                TextField("정확한 기업명", text: $newName).textFieldStyle(.roundedBorder)
            }
        }
    }
}
