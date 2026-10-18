import Foundation

/// 볼트 경로에서 12.0을 찾아 읽는다. 실패 원인을 구분해 "조회 불가"를 "라벨 없음"과 섞이지 않게 한다.
public enum ApplicationStatusLoader {
    public enum LoadError: Error, Equatable {
        case vaultNotAFolder
        case statusFileNotFound
        /// 파일은 있으나 읽기 거부 · 인코딩 오류
        case unreadable
        case noStatusTable
    }

    public struct Loaded: Equatable, Sendable {
        public let layout: VaultLayout
        public let result: ApplicationStatusParser.Result
    }

    /// 설정에 적은 위치로 읽는다 (항목별 경로, 2026-10-18)
    public static func load(paths: VaultPaths) throws(LoadError) -> Loaded {
        let layout = paths.layout
        guard FileManager.default.fileExists(atPath: layout.statusFile.path) else { throw .statusFileNotFound }
        guard let markdown = try? String(contentsOf: layout.statusFile, encoding: .utf8) else { throw .unreadable }
        do {
            return Loaded(layout: layout, result: try ApplicationStatusParser.parse(markdown))
        } catch {
            throw .noStatusTable
        }
    }

    public static func load(vault root: URL) throws(LoadError) -> Loaded {
        let layout: VaultLayout
        do {
            layout = try VaultLocator.locate(vault: root)
        } catch .notAFolder {
            throw .vaultNotAFolder
        } catch {
            throw .statusFileNotFound
        }

        guard let markdown = try? String(contentsOf: layout.statusFile, encoding: .utf8) else {
            throw .unreadable
        }
        do {
            return Loaded(layout: layout, result: try ApplicationStatusParser.parse(markdown))
        } catch {
            throw .noStatusTable
        }
    }
}
