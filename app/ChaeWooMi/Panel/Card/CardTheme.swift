import SwiftUI

/// Figma Foundations 기준 색 (Primary 파인 그린 · Secondary 블러시 핑크 · Neutral 세이지 그레이) 근사값
enum CardTheme {
    static let primary = Color(red: 0.36, green: 0.49, blue: 0.38)
    static let primarySoft = Color(red: 0.92, green: 0.95, blue: 0.92)
    static let caution = Color(red: 0.71, green: 0.29, blue: 0.29)
    static let cautionSoft = Color(red: 0.97, green: 0.89, blue: 0.89)
    static let pending = Color(red: 0.86, green: 0.55, blue: 0.62)
    static let border = Color.black.opacity(0.08)

    /// 카드 폭 (Figma: 자동 220, 수동 170)
    static let cardWidth: CGFloat = 220
    static let manualWidth: CGFloat = 170
    static let chooserWidth: CGFloat = 280
}

/// 둥근 카드 바탕 (얇은 테두리 + 그림자)
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(.background))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(CardTheme.border))
    }
}

extension View {
    func cardBackground() -> some View { modifier(CardBackground()) }
}
