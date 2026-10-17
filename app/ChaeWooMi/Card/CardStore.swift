import ChaeWooMiCore
import Foundation
import Observation

/// 플로팅 카드 상태. 판단은 Core `CardModel`이 하고, 여기서는 볼트 읽기 · 화면 상태만 맡는다.
@MainActor
@Observable
final class CardStore {
    private(set) var model = CardModel()
    /// nil이면 볼트 경로가 없음
    private(set) var loaded: ApplicationStatusLoader.Loaded?
    private(set) var loadError: ApplicationStatusLoader.LoadError?
    /// 지원 버튼이 카드 자리를 가림 → 런처로 접는다 (APP-015)
    private(set) var applyButtonCovering = false
    /// 상세 펼침 (APP-002 · APP-014)
    var expanded = false
    /// 사용자가 접은 상태
    var collapsed = false
    /// 다음 단계에서 붙는 동작을 눌렀을 때 짧은 안내
    var notice: String?

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private lazy var watcher = VaultWatcher { [weak self] in self?.vaultChanged() }
    @ObservationIgnored private var watchedPath: String?

    init(settings: AppSettings) {
        self.settings = settings
    }

    var content: CardModel.Content { model.content }

    /// 카드를 접어 런처만 보일지
    var showsLauncherOnly: Bool {
        content == .hidden || collapsed || applyButtonCovering
    }

    func start() {
        reloadVault()
    }

    func handle(_ event: CardModel.Event) {
        if case .page = event { resetView() }
        if case .pageLeft = event { resetView() }
        model.handle(event, lookup: lookup)
    }

    func applyButton(covering: Bool) {
        applyButtonCovering = covering
    }

    /// 볼트 경로가 바뀌었거나 파일이 바뀜
    func reloadVault() {
        guard let path = settings.vaultPath, !path.isEmpty else {
            loaded = nil
            loadError = nil
            watcher.watch(nil)
            watchedPath = nil
            return
        }
        let root = URL(fileURLWithPath: path, isDirectory: true)
        do {
            loaded = try ApplicationStatusLoader.load(vault: root)
            loadError = nil
        } catch {
            loaded = nil
            loadError = error
        }
        if watchedPath != path {
            watcher.watch(root)
            watchedPath = path
        }
    }

    func lookup(_ names: [String]) -> CompanyLookup {
        if let loadError {
            return .resolve(candidates: names, status: .failure(loadError), today: .today())
        }
        guard let loaded else { return .unavailable(.vaultNotSet) }
        return .resolve(candidates: names, status: .success(loaded.result.records), today: .today())
    }

    /// 지금 확정된 회사 (수동 카드 결과 포함)
    var confirmedCompany: String? {
        switch content {
        case let .company(name, .caution), let .company(name, .clear): name
        case .manual(.caution(let name, _)?), .manual(.clear(let name, _)?): name
        default: nil
        }
    }

    /// 12.0에서 이 회사의 행 (상세 지원 기록)
    func records(for company: String) -> [ApplicationRecord] {
        let key = CompanyName.normalize(company)
        return (loaded?.result.records ?? [])
            .filter { CompanyName.normalize($0.company) == key }
            .sorted { $0.lastSubmitted > $1.lastSubmitted }
    }

    /// 회사 선택 모달의 최근 지원일
    func latestSubmitted(_ company: String) -> CalendarDay? {
        records(for: company).first?.lastSubmitted
    }

    func folders(for company: String) -> CompanyFolders? {
        loaded.map { CompanyFolders.find(company: company, in: $0.layout) }
    }

    /// 아이콘 상태 (APP-012). 회사가 확정되지 않았으면 사용 불가
    func taskState(_ kind: TaskKind) -> TaskState {
        let company = confirmedCompany
        return TaskStateRule.state(
            kind,
            folders: company.flatMap(folders(for:)),
            running: [],
            failures: [:],
            unavailableReason: company == nil ? "회사를 먼저 확인하세요" : nil
        )
    }

    /// 공고가 바뀌면 화면 상태를 처음으로. 지원 버튼 가림도 새 공고 탭이 다시 알려 줄 때까지 푼다
    private func resetView() {
        expanded = false
        collapsed = false
        notice = nil
        applyButtonCovering = false
    }

    private func vaultChanged() {
        reloadVault()
        handle(.recheck)
    }
}
