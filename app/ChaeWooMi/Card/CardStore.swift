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
    /// 문서 · 분석 진행 (아이콘의 진행 중 · 실패 · 다른 문서 작업 중을 덮어쓴다)
    @ObservationIgnored weak var documents: DocumentController?
    /// 지원 기록 (12.0이 바뀌면 반영을 확인한다)
    @ObservationIgnored weak var records: RecordController?
    /// 확장에 지금 탭을 다시 읽어 달라고 보낸다. 보낼 연결이 없으면 false
    @ObservationIgnored var requestRescan: (@MainActor () -> Bool)?
    @ObservationIgnored private var rescanFallback: Task<Void, Never>?
    @ObservationIgnored private lazy var watcher = VaultWatcher { [weak self] in self?.vaultChanged() }
    @ObservationIgnored private var watchedPaths: VaultPaths?

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

    /// "지원 이력 확인" 버튼: 접힌 카드는 펼치고, 카드가 없으면 지금 공고를 다시 읽는다.
    /// 잠시 기다려도 공고가 오지 않으면(지정 외 사이트 · 브라우저 연결 없음) 수동 조회 카드를 연다
    func checkHistory() {
        guard content == .hidden else {
            collapsed = false
            return
        }
        rescanFallback?.cancel()
        guard requestRescan?() == true else {
            handle(.manualActivated)
            return
        }
        rescanFallback = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.rescanWait))
            guard !Task.isCancelled, let self, content == .hidden else { return }
            handle(.manualActivated)
        }
    }

    /// 다시 읽기를 기다리는 시간 (사람인은 본문을 늦게 불러와 회사명이 늦게 나올 수 있음)
    static let rescanWait: Double = 2.5

    func applyButton(covering: Bool) {
        applyButtonCovering = covering
    }

    /// 저장 위치가 바뀌었거나 파일이 바뀜
    func reloadVault() {
        let paths = settings.vaultPaths
        guard !paths.statusFile.isEmpty else {
            loaded = nil
            loadError = nil
            watcher.watch([])
            watchedPaths = nil
            return
        }
        do {
            loaded = try ApplicationStatusLoader.load(paths: paths)
            loadError = nil
        } catch {
            loaded = nil
            loadError = error
        }
        if watchedPaths != paths {
            let layout = paths.layout
            watcher.watch([layout.statusFile.deletingLastPathComponent(), layout.activeFolder, layout.outputFolder]
                .compactMap { $0 })
            watchedPaths = paths
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

    /// 아이콘 상태 (APP-012). 볼트 파일 상태 위에 진행 중 · 실패 · 사용 불가를 얹는다
    func taskState(_ kind: TaskKind) -> TaskState {
        let company = confirmedCompany
        return TaskStateRule.state(
            kind,
            folders: company.flatMap(folders(for:)),
            running: documents?.running ?? [],
            failures: documents?.failures ?? [:],
            unavailableReason: unavailableReason(kind, company: company)
        )
    }

    private func unavailableReason(_ kind: TaskKind, company: String?) -> String? {
        if company == nil { return "회사를 먼저 확인하세요" }
        // 수동 카드는 공고 원문이 없어 분석 · 서류를 요청할 수 없다 (APP-018)
        if model.page == nil { return "공고 원문이 없어 지정 사이트 공고에서만 쓸 수 있습니다" }
        return documents?.blockedReason(for: kind)
    }

    private func resetView() {
        expanded = false
        collapsed = false
        notice = nil
        applyButtonCovering = false
    }

    private func vaultChanged() {
        reloadVault()
        handle(.recheck)
        documents?.filesChanged()
        records?.filesChanged()
    }
}
