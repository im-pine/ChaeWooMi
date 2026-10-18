import CoreGraphics

/// 플로팅 패널 위치. 화면 오른쪽 아래 고정 (드래그 이동 · 위치 기억 없음, PRD 3.1).
public enum PanelPlacement {
    /// 런처 크기 (Figma 시안 약 44px)
    public static let launcherSize = CGSize(width: 44, height: 44)
    /// 화면 가장자리 · Dock과의 간격
    public static let margin: CGFloat = 16

    /// `visibleFrame`(메뉴바 · Dock을 뺀 화면 영역, AppKit 좌표 = 아래가 원점) 안의 오른쪽 아래 자리
    public static func bottomRight(size: CGSize, in visibleFrame: CGRect, margin: CGFloat = margin) -> CGRect {
        let width = min(size.width, max(visibleFrame.width - margin * 2, 0))
        let height = min(size.height, max(visibleFrame.height - margin * 2, 0))
        return CGRect(
            x: visibleFrame.maxX - margin - width,
            y: visibleFrame.minY + margin,
            width: width,
            height: height
        )
    }
}
