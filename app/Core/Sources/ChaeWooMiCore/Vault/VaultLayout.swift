import Foundation

/// 볼트 경로에서 찾은 채우미가 읽는 위치.
public struct VaultLayout: Equatable, Sendable {
    public let root: URL
    /// `12.0 지원 현황.md`
    public let statusFile: URL
    /// `12.1 Active` (진행 중 회사 폴더). 없을 수 있다
    public let activeFolder: URL?
    /// `12.2 Archive` (종료 회사 폴더). 없을 수 있다
    public let archiveFolder: URL?
    /// `11.0.0 Output` (이력서 · 자기소개서 산출물). 없을 수 있다
    public let outputFolder: URL?
}

/// 볼트 경로를 받아 12.0 · 회사 폴더 · 산출물 폴더 위치를 이름으로 찾는다.
public enum VaultLocator {
    public enum LocateError: Error, Equatable {
        /// 경로가 없거나 폴더가 아님
        case notAFolder
        /// 볼트 안에 `12.0 지원 현황.md`가 없음
        case statusFileNotFound
    }

    static let statusFileName = "12.0 지원 현황.md"
    static let activePrefix = "12.1 Active"
    static let archivePrefix = "12.2 Archive"
    static let outputPrefix = "11.0.0 Output"
    /// 볼트 루트에서 이 깊이까지만 찾는다 (볼트 전체를 훑지 않음)
    static let maxDepth = 4

    public static func locate(vault root: URL) throws(LocateError) -> VaultLayout {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw .notAFolder
        }
        let found = scan(root)
        guard let statusFile = found.statusFile else { throw .statusFileNotFound }
        return VaultLayout(
            root: root,
            statusFile: statusFile,
            activeFolder: found.active,
            archiveFolder: found.archive,
            outputFolder: found.output
        )
    }

    private struct Found {
        var statusFile: URL?
        var active: URL?
        var archive: URL?
        var output: URL?
    }

    private static func scan(_ root: URL) -> Found {
        var found = Found()
        let keys: [URLResourceKey] = [.isDirectoryKey]
        guard let walker = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return found }

        for case let url as URL in walker {
            if walker.level >= maxDepth { walker.skipDescendants() }
            let name = url.lastPathComponent
            let isDirectory = (try? url.resourceValues(forKeys: Set(keys)).isDirectory) ?? false
            if !isDirectory, name == statusFileName, found.statusFile == nil {
                found.statusFile = url
            } else if isDirectory {
                record(folder: url, named: name, into: &found)
            }
        }
        return found
    }

    private static func record(folder url: URL, named name: String, into found: inout Found) {
        if name.hasPrefix(activePrefix), found.active == nil { found.active = url }
        if name.hasPrefix(archivePrefix), found.archive == nil { found.archive = url }
        if name.hasPrefix(outputPrefix), found.output == nil { found.output = url }
    }
}
