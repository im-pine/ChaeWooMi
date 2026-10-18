import Foundation

/// 항목별 저장 위치와 이름 규칙. 설정에서 정하고, 채우미와 역할 세션이 같은 경로를 쓴다 (사용자 결정, 2026-10-18).
///
/// - 공고 분석: `{postingFolder}/{기업명}/공고.md`
/// - 이력서 · 자기소개서: `{outputFolder}/{기업명} {연도}/{이름}_이력서_{기업명}.md` (· `.pdf`, `_자기소개서_`)
/// - 기업명은 `(주)` · `주식회사` 같은 법인 표기를 뺀 이름
public struct VaultPaths: Codable, Equatable, Sendable {
    /// `12.0 지원 현황.md`
    public var statusFile: String
    /// `12.1 Active` — 공고 분석 회사 폴더가 있는 곳
    public var postingFolder: String
    /// `11.0.0 Output` — 이력서 · 자기소개서 산출물 회사 폴더가 있는 곳
    public var outputFolder: String
    /// 산출물 파일 이름 앞부분 (`{이름}_이력서_…`)
    public var ownerName: String

    public init(statusFile: String, postingFolder: String, outputFolder: String, ownerName: String) {
        self.statusFile = statusFile
        self.postingFolder = postingFolder
        self.outputFolder = outputFolder
        self.ownerName = ownerName
    }

    public static let postingFileName = "공고.md"

    /// 예전 설정(볼트 폴더 하나)에서 이름으로 찾은 값. 못 찾은 항목은 빈칸으로 둔다
    public static func detected(vault root: URL) -> VaultPaths? {
        guard let layout = try? VaultLocator.locate(vault: root) else { return nil }
        return VaultPaths(
            statusFile: layout.statusFile.path,
            postingFolder: layout.activeFolder?.path ?? "",
            outputFolder: layout.outputFolder?.path ?? "",
            ownerName: ""
        )
    }

    /// 앱의 볼트 판정이 쓰는 위치. 지난 공고(Archive)는 공고 분석 폴더 옆 `12.2 Archive`가 있으면 함께 본다
    public var layout: VaultLayout {
        let status = URL(fileURLWithPath: statusFile)
        let posting = Self.folder(postingFolder)
        let archive = posting.map { $0.deletingLastPathComponent().appendingPathComponent("12.2 Archive") }
            .flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
        return VaultLayout(
            root: status.deletingLastPathComponent(),
            statusFile: status,
            activeFolder: posting,
            archiveFolder: archive,
            outputFolder: Self.folder(outputFolder)
        )
    }

    /// 폴더 · 파일 이름에 쓰는 기업명: 법인 표기를 빼고 공백을 정리한다 (`가상전자(주)` → `가상전자`)
    public static func folderName(_ company: String) -> String {
        var text = company.precomposedStringWithCanonicalMapping
        for mark in CompanyName.legalMarks {
            text = text.replacingOccurrences(of: mark, with: " ")
        }
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// 공고 분석 파일 경로. 이미 있는 회사 폴더(표기만 다른 것 포함)가 있으면 그 폴더
    public func postingFile(company: String) -> URL? {
        let folders = CompanyFolders.find(company: company, in: layout)
        if let existing = folders.companyFolders.first {
            return existing.appendingPathComponent(Self.postingFileName)
        }
        return Self.folder(postingFolder)?
            .appendingPathComponent(Self.folderName(company))
            .appendingPathComponent(Self.postingFileName)
    }

    /// 초안 `.md` 경로. 이미 있는 가장 최근 연도 산출물 폴더가 있으면 그 폴더, 없으면 `{기업명} {올해}`
    public func draftFile(_ kind: DocumentKind, company: String, year: Int = CalendarDay.today().year) -> URL? {
        let name = Self.folderName(company)
        let existing = CompanyFolders.find(company: company, in: layout).currentOutputFolders.first
        guard let folder = existing ?? Self.folder(outputFolder)?.appendingPathComponent("\(name) \(year)") else {
            return nil
        }
        let label = kind == .resume ? "이력서" : "자기소개서"
        return folder.appendingPathComponent("\(ownerName)_\(label)_\(name).md")
    }

    /// 항목별 문제 (설정 점검)
    public var problems: [Problem] {
        var found: [Problem] = []
        if !FileManager.default.fileExists(atPath: statusFile) { found.append(.statusFileMissing) }
        if Self.folder(postingFolder) == nil { found.append(.postingFolderMissing) }
        if Self.folder(outputFolder) == nil { found.append(.outputFolderMissing) }
        if ownerName.trimmingCharacters(in: .whitespaces).isEmpty { found.append(.ownerNameMissing) }
        return found
    }

    public enum Problem: Equatable, Sendable {
        case statusFileMissing, postingFolderMissing, outputFolderMissing, ownerNameMissing

        public var message: String {
            switch self {
            case .statusFileMissing: "지원 현황 파일(`12.0 지원 현황.md`)을 선택하세요"
            case .postingFolderMissing: "공고 분석 폴더(`12.1 Active`)를 선택하세요"
            case .outputFolderMissing: "이력서 · 자기소개서 폴더(`11.0.0 Output`)를 선택하세요"
            case .ownerNameMissing: "파일 이름에 쓸 이름을 입력하세요"
            }
        }
    }

    /// 있는 폴더면 URL
    private static func folder(_ path: String) -> URL? {
        var isDirectory: ObjCBool = false
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }
}
