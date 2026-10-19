import AppKit
import ChaeWooMiCore
import SwiftUI

/// 상세의 문서 부분: 진행 상세(AGT-007), 분석 결과(ANL-007), 실패 · 보완 · 다시 시도(ANL-003 · AGT-008),
/// 완료 문서 파일 열기 · Finder(DOC-013 · DOC-014 · DOC-030). 완료 클릭은 조회만 하고 새 요청을 만들지 않는다
struct DocumentDetail: View {
    let store: CardStore
    let documents: DocumentController
    let company: String
    @State private var supplement = ""
    @State private var showsAnalysis = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(progress, id: \.self) { Label($0, systemImage: "hourglass").foregroundStyle(.secondary) }
            failures
            analysisResult
            ForEach([DocumentKind.resume, .coverLetter], id: \.self) { kind in resultFiles(kind) }
        }
    }

    /// 진행 상세: 지금 어느 단계인지만 짧게. 이력서 · 자소서가 함께 진행되면 줄마다
    private var progress: [String] {
        if documents.analysis.requestID != nil { return ["공고 분석 중"] }
        return DocumentKind.allCases.compactMap { kind in
            let step: String? = switch documents.workflow(kind).phase {
            case .analyzing: "공고 분석 후 문서를 만듭니다"
            case .drafting: "초안 작성 중"
            case .commanding: "수정 요청 처리 중"
            case .generatingPDF: "PDF 생성 중"
            default: nil
            }
            return step.map { "\(Self.label(kind)) · \($0)" }
        }
    }

    private static func label(_ kind: DocumentKind) -> String {
        kind == .resume ? "이력서" : "자기소개서"
    }

    @ViewBuilder private var failures: some View {
        if case let .failed(reason, missing) = documents.analysis.phase {
            VStack(alignment: .leading, spacing: 4) {
                Label(reason, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                if !missing.isEmpty { Text("누락: \(missing.joined(separator: ", "))") }
                TextField("보완할 내용", text: $supplement).textFieldStyle(.roundedBorder)
                Button("다시 분석") { documents.retryAnalysis(supplement: supplement.isEmpty ? nil : supplement) }
            }
        }
        ForEach(DocumentKind.allCases, id: \.self) { kind in
            if case let .failed(failure) = documents.workflow(kind).phase {
                VStack(alignment: .leading, spacing: 4) {
                    Label("\(Self.label(kind)) · \(failure.reason)", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    if failure.step == .analysis {
                        TextField("보완할 내용", text: $supplement).textFieldStyle(.roundedBorder)
                    }
                    Button("다시 시도") { documents.retry(kind, supplement: supplement.isEmpty ? nil : supplement) }
                }
            }
        }
    }

    @ViewBuilder private var analysisResult: some View {
        if let folders = store.folders(for: company), let section = PostingAnalysis.section(in: folders) {
            DisclosureGroup("공고 해석", isExpanded: $showsAnalysis) {
                ScrollView { Text(section).font(.system(size: 10)).textSelection(.enabled) }.frame(maxHeight: 160)
            }
        }
    }

    @ViewBuilder private func resultFiles(_ kind: DocumentKind) -> some View {
        if let layout = store.loaded?.layout {
            let snapshot = DocumentSnapshot.read(kind, company: company, layout: layout)
            if snapshot.pdfIsCurrent, let pdf = snapshot.pdf {
                fileRow(pdf)
                if let draft = snapshot.draft { fileRow(draft) }
            }
        }
    }

    /// 파일 열기 · Finder에서 보기. 파일이 옮겨졌거나 지워졌으면 알린다
    private func fileRow(_ url: URL) -> some View {
        HStack {
            Text(url.lastPathComponent).lineLimit(1).truncationMode(.middle)
            Spacer()
            Button("열기") { open(url) { NSWorkspace.shared.open(url) } }.buttonStyle(.link)
            Button("Finder") { open(url) { NSWorkspace.shared.activateFileViewerSelecting([url]) } }.buttonStyle(.link)
        }
    }

    private func open(_ url: URL, action: () -> Void) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            store.notice = "\(url.lastPathComponent) 파일이 옮겨졌거나 지워졌습니다"
            return
        }
        action()
    }
}
