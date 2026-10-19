import AppKit
import ChaeWooMiCore
import SwiftUI

/// 자동 카드 (APP-007): 회사명 · 재지원 판별 · 아이콘 3종 · 상세보기. 안내 문구 없이 짧게
struct CompanyCard: View {
    @Bindable var store: CardStore
    let company: String
    let lookup: CompanyLookup
    let source: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CompanyHeader(company: company.isEmpty ? "회사 확인 필요" : company, source: source, expanded: $store.expanded)
            ReapplyBadge(lookup: lookup) { store.reloadVault(); store.handle(.recheck) }
            TaskIcons(state: store.taskState) { kind, action in handle(kind, action) }
            progressLine
            if let notice = store.notice ?? store.documents?.notice {
                Text(notice).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            if store.expanded, !company.isEmpty {
                DetailSection(store: store, company: company)
            }
        }
        .frame(width: CardTheme.cardWidth - 20, alignment: .leading)
        .cardBackground()
    }

    /// 진행 중인 작업과 단계 (`이력서 · PDF 만드는 중`). 아이콘만으로는 초안 작성 · PDF 생성이 똑같이 보였다
    @ViewBuilder private var progressLine: some View {
        let steps = TaskKind.allCases.compactMap { kind -> String? in
            if case let .running(step) = store.taskState(kind) { return "\(kind.label) · \(step)" }
            return nil
        }
        if let line = steps.last {
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text(line).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }

    /// 아이콘 클릭 분기 (APP-017): 시작 전 = 요청, 진행 중 = 진행 상세, 초안 있음 · 완료 = 검토 모달(재요청 없음),
    /// 공고 분석 완료 = 결과 상세
    private func handle(_ kind: TaskKind, _ action: TaskAction) {
        store.notice = nil
        switch (kind, action) {
        case (.analysis, .start): store.documents?.startAnalysis()
        case (.resume, .start): store.documents?.startDocument(.resume)
        case (.coverLetter, .start): store.documents?.questionsWindow.show()
        case (.resume, .openReview): store.documents?.reopenDraft(.resume)
        case (.coverLetter, .openReview): store.documents?.reopenDraft(.coverLetter)
        case (_, .showProgress), (_, .showFailure): store.expanded = true
        case let (_, .explain(reason)): store.notice = reason
        case (.analysis, .openReview): store.expanded = true
        }
    }
}

/// 상세 (APP-014): 12.0 지원 기록, 문서 상태, 회사 폴더 · 산출물 열기. 작업 상태와 무관하게 항상 진입
struct DetailSection: View {
    let store: CardStore
    let company: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            records
            if let recordController = store.records {
                RecordDetail(records: recordController, company: company)
            }
            Text("문서").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
            ForEach(TaskKind.allCases, id: \.self) { kind in
                row(kind.label, store.taskState(kind).label)
            }
            if let documents = store.documents {
                DocumentDetail(store: store, documents: documents, company: company)
            }
            folderLinks
        }
        .font(.system(size: 11))
    }

    @ViewBuilder private var records: some View {
        let rows = store.records(for: company)
        Text("지원 기록").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
        if let latest = rows.first {
            row("최근 지원", ReapplyInfo.display(latest.lastSubmitted))
            if !latest.role.isEmpty { row("직무", latest.role) }
            if !latest.note.isEmpty { row("비고", latest.note) }
        } else {
            row("최근 지원", "기록 없음")
        }
    }

    @ViewBuilder private var folderLinks: some View {
        if let folders = store.folders(for: company) {
            ForEach(folders.documents + folders.outputFolders, id: \.self) { url in
                Button { NSWorkspace.shared.open(url) } label: {
                    Label(url.lastPathComponent, systemImage: url.hasDirectoryPath ? "folder" : "doc")
                }
                .buttonStyle(.link)
            }
            ForEach(folders.companyFolders, id: \.self) { url in
                Button { NSWorkspace.shared.open(url) } label: { Label("회사 폴더", systemImage: "folder") }
                    .buttonStyle(.link)
                    .help(url.path)
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).lineLimit(1)
        }
    }
}
