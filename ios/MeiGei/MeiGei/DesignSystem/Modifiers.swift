import SwiftUI

extension Theme {
    enum GlowColor {
        case cyan
        case magenta

        var color: SwiftUI.Color {
            switch self {
            case .cyan:    return Theme.Color.accentCyan
            case .magenta: return Theme.Color.accentMagenta
            }
        }
    }

    enum GlowIntensity {
        case sm       // 按钮
        case medium   // 卡片
        case lg       // PR 庆祝爆光

        var outerRadius: CGFloat {
            switch self {
            case .sm:     return 8
            case .medium: return 14
            case .lg:     return 28
            }
        }

        var spreadRadius: CGFloat {
            switch self {
            case .sm:     return 18
            case .medium: return 32
            case .lg:     return 64
            }
        }

        var spreadOpacity: Double {
            switch self {
            case .sm:     return 0.20
            case .medium: return 0.25
            case .lg:     return 0.45
            }
        }

        var strokeOpacity: Double {
            switch self {
            case .sm:     return 0.45
            case .medium: return 0.55
            case .lg:     return 0.75
            }
        }
    }
}

extension View {
    /// 设计稿三层阴影的 SwiftUI 近似：1px stroke overlay + 两层 shadow。
    func neonGlow(_ color: Theme.GlowColor, intensity: Theme.GlowIntensity = .medium, cornerRadius: CGFloat = Theme.Radius.md) -> some View {
        modifier(NeonGlowModifier(color: color.color, intensity: intensity, cornerRadius: cornerRadius))
    }

    /// Surface 卡片：Surface 背景 + Border 描边 + Radius.md + padding 14。
    func cardStyle(padding: CGFloat = Theme.Spacing.md, cornerRadius: CGFloat = Theme.Radius.md) -> some View {
        self
            .padding(padding)
            .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.Color.border, lineWidth: 1)
            )
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

private struct NeonGlowModifier: ViewModifier {
    let color: SwiftUI.Color
    let intensity: Theme.GlowIntensity
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(color.opacity(intensity.strokeOpacity), lineWidth: 1)
            )
            .shadow(color: color.opacity(0.55), radius: intensity.outerRadius)
            .shadow(color: color.opacity(intensity.spreadOpacity), radius: intensity.spreadRadius)
    }
}
