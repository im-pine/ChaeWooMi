import ChaeWooMiCore
import Foundation

/// 볼트 경로 점검 결과를 설정 화면 문구로 바꾼다.
enum VaultCheck {
    static func message(for path: String?) -> (ok: Bool, text: String) {
        guard let path, !path.isEmpty else {
            return (false, "볼트 경로를 지정하세요")
        }
        do {
            let loaded = try ApplicationStatusLoader.load(vault: URL(fileURLWithPath: path, isDirectory: true))
            let skipped = loaded.result.skippedRows
            let suffix = skipped > 0 ? " (읽지 못한 행 \(skipped)개)" : ""
            return (true, "12.0 읽기 성공 · 기록 \(loaded.result.records.count)건\(suffix)")
        } catch {
            return (false, text(for: error))
        }
    }

    private static func text(for error: ApplicationStatusLoader.LoadError) -> String {
        switch error {
        case .vaultNotAFolder: "폴더가 없습니다. 볼트 경로를 다시 지정하세요"
        case .statusFileNotFound: "볼트에서 `12.0 지원 현황.md`를 찾지 못했습니다"
        case .unreadable: "12.0 파일을 읽을 수 없습니다. 파일 권한을 확인하세요"
        case .noStatusTable: "12.0에 회사 · 최근 제출일 열이 있는 표가 없습니다"
        }
    }
}
