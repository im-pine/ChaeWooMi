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
    /// 확장에 지금 탭을 다시 읽어(`reload`면 새로고침해) 달라고 보낸다. 보낼 연결이 없으면 false
    @ObservationIgnored var requestRescan: (@MainActor (Bool) -> Bool)?
    /// 지금 연결된 확장의 버전 (연결 없음이면 nil)
    @ObservationIgnored var extensionVersion: (@MainActor () -> String?)?
    /// "지원 이력 확인" 단계와 직접 입력 대신 알릴 말
    private(set) var historyCheck = HistoryCheck()
    private(set) var historyNotice: String?
    @ObservationIgnored private var historyTimer: Task<Void, Never>?
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
        if case .page = event {
            resetView()
            // 공고가 오면 "지원 이력 확인"은 그 자리에서 끝난다
            historyCheck.found()
            historyTimer?.cancel()
        }
        if case .pageLeft = event { resetView() }
        model.handle(event, lookup: lookup)
    }

    /// "지원 이력 확인" 버튼: 접힌 카드는 펼치고, 카드가 없으면 단계적으로 다시 받아 온다 (Core `HistoryCheck`).
    /// 연결 대기 → 다시 읽기 → 새로고침 → 그래도 회사명이 없으면 직접 입력 (직접 입력은 최후의 수단)
    func checkHistory() {
        guard content == .hidden else {
            collapsed = false
            return
        }
        historyNotice = nil
        apply(historyCheck.start(extensionVersion: extensionVersion?()))
    }

    /// 지금 탭이 지정 사이트 공고가 아님 → 바로 직접 입력
    func notPosting() {
        apply(historyCheck.notPosting())
    }

    /// 확장이 (다시) 연결됨 → 기다리던 확인을 이어 간다
    func extensionConnected(version: String) {
        apply(historyCheck.connected(extensionVersion: version))
    }

    private func apply(_ effects: [HistoryCheck.Effect]) {
        for effect in effects {
            switch effect {
            case let .rescan(reload): _ = requestRescan?(reload)
            case let .manual(reason):
                handle(.manualActivated)
                notice = reason
            case let .notice(text): historyNotice = text
            }
        }
        scheduleHistoryTimeout()
    }

    /// 이 단계의 기다림이 끝나도 카드가 없으면 다음 단계로
    private func scheduleHistoryTimeout() {
        historyTimer?.cancel()
        guard historyCheck.isChecking else { return }
        let wait = historyCheck.wait
        let step = historyCheck.step
        historyTimer = Task { [weak self] in
            try? await Task.sleep(for: wait)
            guard !Task.isCancelled, let self, historyCheck.step == step else { return }
            guard content == .hidden else {
                historyCheck.found()
                return
            }
            apply(historyCheck.timedOut())
        }
    }

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
            running: documents?.running ?? [:],
            failures: documents?.failures ?? [:],
            unavailableReason: unavailableReason(company: company)
        )
    }

    private func unavailableReason(company: String?) -> String? {
        if company == nil { return "회사를 먼저 확인하세요" }
        // 수동 카드는 공고 원문이 없어 분석 · 서류를 요청할 수 없다 (APP-018)
        if model.page == nil { return "공고 원문이 없어 지정 사이트 공고에서만 쓸 수 있습니다" }
        return nil
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
