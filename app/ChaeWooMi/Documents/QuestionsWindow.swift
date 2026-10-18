import AppKit
import ChaeWooMiCore
import SwiftUI

/// 자기소개서 문항 입력 (DOC-005 · DOC-006): 문항 · 글자수 · 공백 포함 여부를 받아 자소서 초안을 요청한다
@MainActor
final class QuestionsWindowController {
    private weak var controller: DocumentController?
    private var window: NSWindow?

    init(controller: DocumentController) {
        self.controller = controller
    }

    func show() {
        guard let controller else { return }
        let view = QuestionsView { [weak self] questions in
            controller.startDocument(.coverLetter, questions: questions)
            self?.window?.orderOut(nil)
        }
        let window = window ?? NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.title = "자기소개서 문항"
        window.contentViewController = NSHostingController(rootView: view)
        window.setContentSize(NSSize(width: 520, height: 420))
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}

private struct QuestionRow: Identifiable {
    let id = UUID()
    var text = ""
    var limit = ""
    var includesSpaces = true
}

struct QuestionsView: View {
    let submit: ([CoverLetterQuestion]) -> Void
    @State private var rows = [QuestionRow()]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach($rows) { $row in rowView($row) }
                }
            }
            Button { rows.append(QuestionRow()) } label: { Label("문항 추가", systemImage: "plus") }
            ForEach(problemTexts, id: \.self) { Text($0).font(.caption).foregroundStyle(.orange) }
            HStack {
                Spacer()
                Button("자기소개서 요청") { submit(questions) }
                    .buttonStyle(.borderedProminent)
                    .tint(CardTheme.primary)
                    .disabled(!CoverLetterQuestion.problems(questions).isEmpty)
            }
        }
        .padding(16)
    }

    private func rowView(_ row: Binding<QuestionRow>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("문항 (붙여넣기 가능)", text: row.text, axis: .vertical).lineLimit(1...4)
            HStack {
                TextField("글자수 (없으면 비움)", text: row.limit).frame(width: 160)
                Toggle("공백 포함", isOn: row.includesSpaces)
                Spacer()
                if rows.count > 1 {
                    let id = row.wrappedValue.id
                    Button { rows.removeAll { $0.id == id } } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.plain)
                }
            }
        }
        .textFieldStyle(.roundedBorder)
    }

    private var questions: [CoverLetterQuestion] {
        rows.map { row in
            CoverLetterQuestion(
                text: row.text,
                limit: Int(row.limit.trimmingCharacters(in: .whitespaces)),
                includesSpaces: row.includesSpaces
            )
        }
    }

    /// 빈 문항 · 잘못된 글자수 안내 (요청 전에)
    private var problemTexts: [String] {
        CoverLetterQuestion.problems(questions).compactMap { problem in
            switch problem {
            case .noQuestions: "문항을 하나 이상 입력하세요"
            case let .emptyQuestion(number): number == 1 && rows.count == 1 ? nil : "\(number)번 문항이 비어 있습니다"
            case let .invalidLimit(number): "\(number)번 문항의 글자수는 1 이상이어야 합니다"
            }
        }
    }
}
