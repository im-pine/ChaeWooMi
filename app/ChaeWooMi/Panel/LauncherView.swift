import SwiftUI

/// 플로팅 런처 (약 44px 원형). 지원 버튼이 카드 자리를 가릴 때 작게 접어 보인다 (APP-015).
/// 색은 브랜드 색으로 고정 (시스템 강조색을 따르면 사용자 설정에 따라 분홍이 됐다)
struct LauncherView: View {
    var body: some View {
        Image(systemName: "leaf.fill")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(Circle().fill(CardTheme.primary))
            .help("채우미")
            .accessibilityLabel("채우미 런처")
    }
}
