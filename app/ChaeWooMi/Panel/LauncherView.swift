import SwiftUI

/// 플로팅 런처 (약 44px 원형). 공고가 없거나 카드를 접었을 때 보인다.
struct LauncherView: View {
    var body: some View {
        Image(systemName: "leaf.fill")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(Circle().fill(Color.accentColor))
            .help("채우미")
            .accessibilityLabel("채우미 런처")
    }
}
