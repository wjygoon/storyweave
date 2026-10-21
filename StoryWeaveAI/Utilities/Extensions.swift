import SwiftUI
import UIKit

// MARK: - Haptic Feedback
/// 触觉反馈工具类

enum HapticManager {
    
    /// 轻微碰撞反馈
    static func light() {
        guard UserPreferences.shared.hapticFeedbackEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    /// 中等碰撞反馈
    static func medium() {
        guard UserPreferences.shared.hapticFeedbackEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// 沉重碰撞反馈
    static func heavy() {
        guard UserPreferences.shared.hapticFeedbackEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    /// 选择反馈
    static func selection() {
        guard UserPreferences.shared.hapticFeedbackEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    /// 成功反馈
    static func success() {
        guard UserPreferences.shared.hapticFeedbackEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    /// 错误反馈
    static func error() {
        guard UserPreferences.shared.hapticFeedbackEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    /// 警告反馈
    static func warning() {
        guard UserPreferences.shared.hapticFeedbackEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}

// MARK: - View Extensions

extension View {
    /// 隐藏键盘
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    /// 可点击扩展背景
    func expandTapableArea() -> some View {
        background(Color.clear)
    }
    
    /// 条件应用修饰符
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
