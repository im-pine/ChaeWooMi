import AppKit
import ChaeWooMiCore
import SwiftUI

/// 문서 검토 모달 (DOC-017): 왼쪽 Markdown 편집 · 오른쪽 수정 명령, 아래 초안 보관 / 승인 · 파일 생성
struct ReviewView: View {
    let controller: DocumentController
    @Bindable var model: ReviewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                EditorPane(model: model, locked: controller.workflow.editingLocked)
                Divider()
                CommandPane(controller: controller, model: model)
                    .frame(width: 380)
            }
            Divider()
            ReviewFooter(controller: controller, model: model)
        }
        .frame(minWidth: 960, minHeight: 600)
    }
}

/// 왼쪽: 편집 / 잠금 스위치. 명령 처리 중에는 잠금으로 고정 (DOC-018 · DOC-026)
private struct EditorPane: View {
    @Bindable var model: ReviewModel
    let locked: Bool
    @State private var editing = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.draft?.lastPathComponent ?? "").font(.headline)
                Spacer()
                Picker("", selection: Binding(get: { editing && !locked }, set: { editing = $0 })) {
                    Text("편집").tag(true)
                    Text("잠금").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                .disabled(locked)
                .help(locked ? "수정 명령 처리 중에는 잠깁니다" : "편집 / 잠금")
            }
            Text(model.draft?.path ?? "")
                .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            if editing && !locked {
                TextEditor(text: $model.text).font(.system(.body, design: .monospaced))
            } else {
                ScrollView { Text(preview).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
            }
            if let error = model.saveError { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .padding(16)
    }

    /// 잠금 상태는 렌더링된 미리보기
    private var preview: AttributedString {
        (try? AttributedString(
            markdown: model.text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(model.text)
    }
}

/// 오른쪽: 내가 보낸 명령과 상태만 (AI 답변 문장은 보이지 않음, DOC-019 · DOC-029), CAREER-DB 반영 요청 카드 (DOC-031)
private struct CommandPane: View {
    let controller: DocumentController
    let model: ReviewModel
    @State private var input = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Claude 수정 요청").font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(controller.workflow.commands, id: \.id) { CommandRow(command: $0) }
                    ForEach(controller.workflow.careerRequests, id: \.self) { CareerCard(text: $0) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                TextField("수정할 내용을 입력하세요", text: $input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .onSubmit(send)
                Button("전송", action: send).disabled(!canSend)
            }
        }
        .padding(16)
    }

    /// 처리 중에는 보내지 않는다 (DOC-027)
    private var canSend: Bool {
        controller.workflow.phase == .reviewing && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        guard canSend else { return }
        controller.command(input, userEdited: model.userEdited)
        model.markSent()
        input = ""
    }
}

private struct CommandRow: View {
    let command: DocumentWorkflow.Command

    var body: some View {
        HStack(alignment: .top) {
            Text(command.text).frame(maxWidth: .infinity, alignment: .leading)
            switch command.status {
            case .running: ProgressView().controlSize(.small).help("처리 중")
            case .completed: Image(systemName: "checkmark.circle.fill").foregroundStyle(CardTheme.primary).help("완료")
            case let .failed(reason):
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red).help(reason)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
    }
}

/// 세션이 돌려준 CAREER-DB 반영 요청. 복사해서 CAREER-DB 세션에 직접 전달한다 (자동 전달 없음)
private struct CareerCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("CAREER-DB 반영 요청", systemImage: "tray.and.arrow.up").font(.subheadline.weight(.semibold))
                Spacer()
                Button("복사") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
            }
            Text(text).font(.caption).textSelection(.enabled)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).stroke(CardTheme.border))
    }
}

/// 푸터: 같은 크기(184×40, 간격 12) 두 버튼, 아이콘 없이 글자 가운데 (DOC-023). 실패 · 진행 상태도 여기서 알린다
private struct ReviewFooter: View {
    let controller: DocumentController
    let model: ReviewModel

    static let buttonSize = CGSize(width: 184, height: 40)

    var body: some View {
        HStack(spacing: 12) {
            status
            Spacer()
            footerButton("초안 보관") { controller.archive() }
            footerButton("승인 · 파일 생성", prominent: true) {
                controller.approve(userEdited: model.userEdited)
                model.markSent()
            }
        }
        .padding(16)
    }

    private func footerButton(_ title: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(width: Self.buttonSize.width, height: Self.buttonSize.height)
                .multilineTextAlignment(.center)
                // plain 스타일은 글자만 눌리므로 184×40 전체를 누르는 영역으로
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(prominent ? Color.white : Color.primary)
        .background(
            RoundedRectangle(cornerRadius: 8).fill(prominent ? CardTheme.primary : Color.secondary.opacity(0.12))
        )
        .disabled(controller.workflow.phase != .reviewing)
    }

    @ViewBuilder private var status: some View {
        switch controller.workflow.phase {
        case .generatingPDF:
            Label("PDF를 만드는 중", systemImage: "hourglass").foregroundStyle(.secondary)
        case .completed:
            Label("PDF 생성 완료", systemImage: "checkmark.circle.fill").foregroundStyle(CardTheme.primary)
        case let .failed(failure):
            HStack {
                Label(failure.reason, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                Button("다시 시도") { controller.retry() }
            }
        default:
            EmptyView()
        }
    }
}
