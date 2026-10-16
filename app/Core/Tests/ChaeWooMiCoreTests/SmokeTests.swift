import Testing
@testable import ChaeWooMiCore

/// 테스트 환경이 동작하는지만 확인한다. 기능 테스트는 기능 PR과 함께 추가한다.
@Test("모듈을 불러올 수 있다")
func moduleLoads() {
    #expect(ChaeWooMiCore.version == "0.1.0")
}
