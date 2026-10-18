import Foundation

/// "지원 이력 확인" 버튼의 단계 (사용자 결정, 2026-10-18). 회사명 직접 입력은 최후의 수단이다:
/// 브라우저 연결 대기 → 지금 탭 다시 읽기 → 지금 탭 새로고침 → 그래도 회사명이 없으면 직접 입력.
/// 공고가 오면(카드가 뜨면) 그 자리에서 끝난다.
public struct HistoryCheck: Equatable, Sendable {
    public enum Step: Equatable, Sendable {
        case idle
        /// 앱을 다시 켜 확장 연결이 끊긴 상태 → 확장이 다시 이어지기를 기다림 (확장은 30초마다 조용히 다시 연결)
        case waitingConnection
        /// 지금 탭을 다시 읽음 (끊긴 탭이면 확장이 스크립트를 다시 넣음)
        case rescanning
        /// 지금 탭을 새로고침함 (지정 사이트 탭만)
        case reloading
    }

    public enum Effect: Equatable, Sendable {
        case rescan(reload: Bool)
        /// 직접 입력 카드를 연다 (이유와 함께)
        case manual(reason: String)
        /// 직접 입력 대신 사용자에게 알린다 (예전 확장)
        case notice(String)
    }

    /// 다시 읽기(`rescan`)를 아는 확장 버전
    public static let minimumExtensionVersion = "0.2.0"

    public private(set) var step: Step = .idle

    public init() {}

    public var isChecking: Bool { step != .idle }

    /// 지금 단계를 사람에게 보이는 말
    public var label: String? {
        switch step {
        case .idle: nil
        case .waitingConnection: "브라우저 연결 기다리는 중"
        case .rescanning: "화면 다시 읽는 중"
        case .reloading: "페이지 새로고침 중"
        }
    }

    /// 이 단계에서 공고를 기다리는 시간
    public var wait: Duration {
        switch step {
        case .idle: .zero
        case .waitingConnection: .seconds(35)
        case .rescanning: .seconds(4)
        case .reloading: .seconds(12)
        }
    }

    /// 버튼을 누름. `extensionVersion`은 지금 연결된 확장의 버전 (연결 없음이면 nil)
    public mutating func start(extensionVersion: String?) -> [Effect] {
        guard step == .idle else { return [] }
        guard let extensionVersion else {
            step = .waitingConnection
            return []
        }
        return begin(extensionVersion)
    }

    /// 확장이 (다시) 연결됨
    public mutating func connected(extensionVersion: String) -> [Effect] {
        guard step == .waitingConnection else { return [] }
        return begin(extensionVersion)
    }

    /// 공고가 와서 카드가 뜸 → 끝
    public mutating func found() {
        step = .idle
    }

    /// 확장이 "지금 탭은 지정 사이트 공고가 아님"을 알림 → 다시 읽기 · 새로고침이 소용없으니 바로 직접 입력
    public mutating func notPosting() -> [Effect] {
        guard step == .rescanning || step == .reloading else { return [] }
        step = .idle
        return [.manual(reason: "지정 사이트 공고 페이지가 아니라 회사명을 직접 입력합니다")]
    }

    /// 이 단계의 기다림이 끝났는데 공고가 오지 않음 → 다음 단계
    public mutating func timedOut() -> [Effect] {
        switch step {
        case .idle:
            return []
        case .waitingConnection:
            step = .idle
            return [.manual(reason: "브라우저 확장과 연결되지 않아 회사명을 직접 입력합니다")]
        case .rescanning:
            step = .reloading
            return [.rescan(reload: true)]
        case .reloading:
            step = .idle
            return [.manual(reason: "이 페이지에서 회사명을 찾지 못해 직접 입력합니다")]
        }
    }

    private mutating func begin(_ version: String) -> [Effect] {
        guard Self.isAtLeast(version, Self.minimumExtensionVersion) else {
            step = .idle
            return [.notice("채우미 확장을 새로고침(↻)하세요 — 예전 확장은 화면을 다시 읽지 못합니다")]
        }
        step = .rescanning
        return [.rescan(reload: false)]
    }

    /// `0.10.0` ≥ `0.2.0`처럼 점으로 나눈 숫자로 비교
    static func isAtLeast(_ version: String, _ minimum: String) -> Bool {
        let parts = { (text: String) in text.split(separator: ".").map { Int($0) ?? 0 } }
        let lhs = parts(version), rhs = parts(minimum)
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left > right }
        }
        return true
    }
}
