import SwiftUI

extension Theme {
    /// 纸感阴影三级，数值对齐 C 设计稿 sh-sm / sh-md / sh-lg（阴影底色 = fg #1c1a17）。
    enum ShadowLevel {
        case sm   // 卡片、按钮
        case md   // 中等高度（徽章、浮层）
        case lg   // Sheet、Dialog

        var opacity: Double {
            switch self {
            case .sm: return 0.07
            case .md: return 0.09
            case .lg: return 0.12
            }
        }
        var radius: CGFloat {
            switch self {
            case .sm: return 4
            case .md: return 8
            case .lg: return 16
            }
        }
        var y: CGFloat {
            switch self {
            case .sm: return 1
            case .md: return 4
            case .lg: return 8
            }
        }
    }

}

extension View {
    /// 纸感投影：柔和 drop shadow + ~0.5px 描边近似（无彩色辉光）。
    func paperShadow(_ level: Theme.ShadowLevel = .sm, cornerRadius: CGFloat = Theme.Radius.md) -> some View {
        self
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.Color.fg.opacity(0.04), lineWidth: 0.5)
            )
            .shadow(color: Theme.Color.fg.opacity(level.opacity), radius: level.radius, x: 0, y: level.y)
    }

    /// Surface 卡片：白底 + Border 描边 + 圆角 + padding + 纸感阴影。
    func cardStyle(padding: CGFloat = Theme.Spacing.md, cornerRadius: CGFloat = Theme.Radius.md) -> some View {
        self
            .padding(padding)
            .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.Color.border, lineWidth: 1)
            )
            .shadow(color: Theme.Color.fg.opacity(Theme.ShadowLevel.sm.opacity), radius: Theme.ShadowLevel.sm.radius, x: 0, y: Theme.ShadowLevel.sm.y)
    }

    /// 等宽小字 ALL CAPS + tracking + muted。常用于栏目标签。
    func eyebrowStyle() -> some View {
        self
            .font(Theme.Font.mono(size: 10, weight: .semibold))
            .tracking(0.08 * 10)              // 0.08em ≈ tracking 0.8pt
            .textCase(.uppercase)
            .foregroundStyle(Theme.Color.muted)
    }

    /// 等宽数字：JetBrains Mono + monospacedDigit + 紧字距。
    func numStyle(size: CGFloat, weight: Font.Weight = .semibold) -> some View {
        self
            .font(Theme.Font.number(size: size, weight: weight))
            .tracking(-0.02 * size)
    }
}

/// 按压微反馈样式：按下时轻微缩小（0.97，不引发布局位移）+ 降不透明度，`.easeOut(0.12)`。
/// 尊重「减弱动态效果」：开启 `accessibilityReduceMotion` 时退化为仅不透明度变化、不缩放。
struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.97 : 1.0))
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
