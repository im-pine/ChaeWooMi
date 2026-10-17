import Foundation
import Testing
@testable import ChaeWooMiCore

@Suite("공고 진입 시 자동 실행 스위치 (APP-019)")
struct AutoLaunchPolicyTests {
    private func defaults() -> (UserDefaults, String) {
        let name = "chaewoomi-test-\(UUID())"
        return (UserDefaults(suiteName: name)!, name)
    }

    @Test("값이 없으면(처음) 자동 실행을 켠다")
    func defaultOn() {
        let (store, name) = defaults()
        defer { store.removePersistentDomain(forName: name) }
        #expect(AutoLaunchPolicy.isEnabled(store))
        #expect(AutoLaunchPolicy.isEnabled(nil))
    }

    @Test("메뉴바 스위치를 끄면 자동 실행하지 않는다 (QA-062)")
    func switchedOff() {
        let (store, name) = defaults()
        defer { store.removePersistentDomain(forName: name) }
        store.set(false, forKey: AutoLaunchPolicy.key)
        #expect(!AutoLaunchPolicy.isEnabled(store))
        store.set(true, forKey: AutoLaunchPolicy.key)
        #expect(AutoLaunchPolicy.isEnabled(store))
    }
}
