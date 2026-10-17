import Foundation

/// 확정한 회사의 볼트 폴더 (MAT-016). 정규화한 회사명으로 폴더 이름을 맞춘다.
public struct CompanyFolders: Equatable, Sendable {
    /// `12.1 Active/<회사>/` · `12.2 Archive/<연도>/<회사>/`
    public let companyFolders: [URL]
    /// `11.0.0 Output/<회사> <연도>/`
    public let outputFolders: [URL]

    /// 가장 최근 연도의 산출물 폴더. 다음 해에 다시 지원하면 새 연도 폴더를 만들므로 지난 지원 산출물로 아이콘을 정하지 않는다
    public var currentOutputFolders: [URL] {
        let years = outputFolders.map { Self.year(of: $0.lastPathComponent) }
        guard let latest = years.max() else { return [] }
        return zip(outputFolders, years).filter { $0.1 == latest }.map(\.0)
    }

    /// `가상전자 2026` → 2026, 연도가 없으면 0
    static func year(of name: String) -> Int {
        guard let range = name.range(of: #"\d{4}$"#, options: .regularExpression) else { return 0 }
        return Int(name[range]) ?? 0
    }

    /// 회사 폴더 후보가 둘 이상이면 사용자 확인
    public var needsConfirmation: Bool { companyFolders.count > 1 }

    /// 회사 폴더 문서 (공고 · 기업 리서치 · 제출본) 중 있는 것
    public var documents: [URL] {
        companyFolders.flatMap { folder in
            Self.documentNames.map { folder.appendingPathComponent($0) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }
        }
    }

    public static let documentNames = ["공고.md", "기업 리서치.md", "제출본.md"]

    public static func find(company: String, in layout: VaultLayout) -> CompanyFolders {
        let key = CompanyName.normalize(company)
        let active = layout.activeFolder.map { subfolders(of: $0) } ?? []
        let archive = (layout.archiveFolder.map { subfolders(of: $0) } ?? []).flatMap { subfolders(of: $0) }
        let output = layout.outputFolder.map { subfolders(of: $0) } ?? []
        return CompanyFolders(
            companyFolders: (active + archive).filter { CompanyName.normalize($0.lastPathComponent) == key },
            outputFolders: output.filter { CompanyName.normalize(withoutYear($0.lastPathComponent)) == key }
        )
    }

    /// `가상전자 2026` → `가상전자`
    static func withoutYear(_ name: String) -> String {
        guard let range = name.range(of: #"\s+\d{4}$"#, options: .regularExpression) else { return name }
        return String(name[..<range.lowerBound])
    }

    private static func subfolders(of folder: URL) -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return items
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
