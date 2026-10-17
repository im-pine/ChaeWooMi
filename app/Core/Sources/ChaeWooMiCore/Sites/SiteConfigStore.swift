import Foundation

/// 앱 소유 설정 파일 (`~/Library/Application Support/ChaeWooMi/sites.json`). 볼트가 아니다.
/// 없으면 기본값으로 만들고, 틀렸으면 기본값으로 동작하면서 문제를 알린다.
public enum SiteConfigStore {
    public struct Loaded: Equatable, Sendable {
        /// 실제로 쓰는 설정 (파일이 틀렸으면 기본값)
        public let config: SiteConfig
        /// 파일 문제. 비어 있으면 파일 설정을 그대로 씀
        public let problems: [String]

        public init(config: SiteConfig, problems: [String]) {
            self.config = config
            self.problems = problems
        }
    }

    public static func defaultURL(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home.appendingPathComponent("Library/Application Support/ChaeWooMi/sites.json")
    }

    public static func load(from url: URL, fallback: SiteConfig = .defaultConfig) -> Loaded {
        if !FileManager.default.fileExists(atPath: url.path) {
            writeDefault(fallback, to: url)
            return Loaded(config: fallback, problems: [])
        }
        let config: SiteConfig
        do {
            config = try SiteConfig.decode(Data(contentsOf: url))
        } catch {
            return Loaded(config: fallback, problems: ["sites.json을 읽지 못했습니다: \(error.localizedDescription)"])
        }
        let problems = SiteConfigValidator.problems(in: config)
        return problems.isEmpty
            ? Loaded(config: config, problems: [])
            : Loaded(config: fallback, problems: problems.map(\.description))
    }

    private static func writeDefault(_ config: SiteConfig, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(config) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
