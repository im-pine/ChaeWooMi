import ChaeWooMiCore
import SwiftUI

/// 제출 정보 확인 폼 (HIS-002): 회사 · 직무 · 플랫폼 · 제출일(기본 서울 기준 오늘, 고칠 수 있음)을 확인한 뒤 기록을 요청한다
struct RecordForm: View {
    @State var submission: Submission
    let problem: Submission.Problem?
    let submit: (Submission) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            field("회사", $submission.company)
            field("직무", $submission.role)
            field("플랫폼", $submission.platform)
            field("제출일", $submission.submitted, prompt: "YYYY-MM-DD")
            if let problem {
                Text(problem.message).font(.system(size: 10)).foregroundStyle(.red)
            }
            Button("12.0에 기록 요청") { submit(submission) }
                .controlSize(.small)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func field(_ title: String, _ value: Binding<String>, prompt: String? = nil) -> some View {
        HStack(spacing: 6) {
            Text(title).foregroundStyle(.secondary).frame(width: 40, alignment: .leading)
            TextField(title, text: value, prompt: prompt.map { Text($0) })
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .accessibilityLabel(title)
        }
        .font(.system(size: 11))
    }
}

/// 상세의 지원 완료 기록 (HIS-001 · HIS-016). 컴팩트 카드에는 넣지 않고 상세에서만 연다
struct RecordDetail: View {
    let records: RecordController
    let company: String
    @State private var opened = false

    var body: some View {
        if opened {
            RecordForm(submission: records.draft(company: company), problem: records.workflow.problem) {
                records.confirm($0)
                if records.workflow.problem == nil { opened = false }
            }
        } else {
            Button("지원 완료 기록") { opened = true }
                .buttonStyle(.link)
                .disabled(records.workflow.isBusy)
                .help("감지되지 않은 지원을 직접 기록합니다. 문서 완성만으로는 기록하지 않습니다")
        }
    }
}

/// 지원 완료 카드 (HIS-017): 감지 → 5초 카운트다운(취소 / 기록) → 기록 중 → 12.0에서 확인한 결과
struct ApplyCompleteCard: View {
    let records: RecordController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("지원 완료").font(.system(size: 12, weight: .semibold))
            content
        }
        .font(.system(size: 11))
        .frame(width: CardTheme.cardWidth - 20, alignment: .leading)
        .cardBackground()
    }

    @ViewBuilder private var content: some View {
        if let notice = records.notice {
            Label(notice, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
        }
        if let form = records.form {
            if records.notice == nil, records.workflow.problem == nil {
                Text("회사를 확인한 뒤 기록하세요").foregroundStyle(.secondary)
            }
            RecordForm(submission: form, problem: records.workflow.problem) { records.confirm($0) }
            Button("닫기") { records.dismiss() }.controlSize(.small)
        } else {
            phase
        }
    }

    @ViewBuilder private var phase: some View {
        switch records.workflow.phase {
        case let .countdown(remaining, submission):
            Text(submission.company).font(.system(size: 13, weight: .semibold))
            Text("\(remaining)초 뒤 12.0에 기록합니다").foregroundStyle(.secondary)
            HStack {
                Button("취소") { records.cancel() }
                Button("기록") { records.recordNow() }.keyboardShortcut(.defaultAction)
            }
            .controlSize(.small)
        case let .recording(_, company, _):
            Text(company).font(.system(size: 13, weight: .semibold))
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("12.0에 기록 중")
            }
        case let .recorded(company, day):
            Label("\(company) · \(ReapplyInfo.display(day)) 기록됨", systemImage: "checkmark.circle.fill")
                .foregroundStyle(CardTheme.primary)
            Button("닫기") { records.dismiss() }.controlSize(.small)
        case let .failed(reason):
            Label(reason, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
            HStack {
                Button("고쳐서 기록") { records.edit() }
                Button("닫기") { records.dismiss() }
            }
            .controlSize(.small)
        case .idle:
            EmptyView()
        }
    }
}
