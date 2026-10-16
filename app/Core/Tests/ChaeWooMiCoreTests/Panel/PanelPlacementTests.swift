import CoreGraphics
import Testing
@testable import ChaeWooMiCore

@Suite("플로팅 패널 위치")
struct PanelPlacementTests {
    @Test("런처는 화면 보이는 영역의 오른쪽 아래에 여백 16을 두고 놓인다")
    func bottomRight() {
        let visible = CGRect(x: 0, y: 70, width: 1440, height: 805) // Dock 70 · 메뉴바 25 제외
        let frame = PanelPlacement.bottomRight(size: PanelPlacement.launcherSize, in: visible)
        #expect(frame == CGRect(x: 1440 - 16 - 44, y: 70 + 16, width: 44, height: 44))
    }

    @Test("보조 모니터(원점이 음수)에서도 그 화면 안에 놓인다")
    func secondaryScreen() {
        let visible = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
        let frame = PanelPlacement.bottomRight(size: CGSize(width: 220, height: 104), in: visible)
        #expect(visible.contains(frame))
        #expect(frame.maxX == visible.maxX - 16)
        #expect(frame.minY == visible.minY + 16)
    }

    @Test("화면보다 큰 패널은 화면 안으로 줄인다")
    func clampsToScreen() {
        let visible = CGRect(x: 0, y: 0, width: 100, height: 60)
        let frame = PanelPlacement.bottomRight(size: CGSize(width: 220, height: 104), in: visible)
        #expect(visible.contains(frame))
        #expect(frame.size == CGSize(width: 68, height: 28))
    }
}
