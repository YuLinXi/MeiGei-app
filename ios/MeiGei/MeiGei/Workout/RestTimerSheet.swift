import SwiftUI
import UIKit

/// 休息计时全屏弹窗（设计稿 02b）。
///
/// 由 `WorkoutSessionView` 通过 `if isRestExpanded` 条件渲染，
/// ZStack overlay 在训练页之上；点击空白不关闭，必须点「最小化」回到 FAB。
struct RestTimerSheet: View {
    let controller: RestTimerController
    /// 下一组提示：「动作名 · 第 N 组」。
    let nextHint: String?
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // 半透明背景：先磨砂再压一层 bg，避免下层 List 透光发亮。
            Theme.Color.bg.opacity(0.92)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
            content
        }
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    private var content: some View {
        VStack(spacing: Theme.Spacing.lg) {
            HStack {
                pillButton(icon: "iphone.radiowaves.left.and.right", label: "手机震动") {
                    Theme.Haptics.impact(.medium)
                }
                Spacer()
                pillButton(icon: "arrow.down.right.and.arrow.up.left", label: "最小化", action: onDismiss)
            }

            Spacer(minLength: 0)

            VStack(spacing: Theme.Spacing.md) {
                Text("REST · 休息计时").eyebrowStyle()
                bigRing
                if let nextHint {
                    Text(nextHint)
                        .font(Theme.Font.body(size: 13))
                        .foregroundStyle(Theme.Color.fg2)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: Theme.Spacing.md) {
                actionButton("−10s") { controller.adjust(by: -10) }
                actionButton("完成", emphasized: true) {
                    Theme.Haptics.notification(.success)
                    controller.stop()
                    onDismiss()
                }
                actionButton("+10s") { controller.adjust(by: 10) }
            }
        }
        .padding(Theme.Spacing.lg)
    }

    private var bigRing: some View {
        // 让 TimelineView 每秒驱动重绘，不靠手动 Timer（与 FAB 共享同一墙钟 endDate）。
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            let total = controller.totalDuration
            let remaining = controller.remaining
            let progress = total > 0 ? min(max(remaining / total, 0), 1) : 0
            ZStack {
                Circle()
                    .stroke(Theme.Color.border, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Theme.Color.accentCyan, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Theme.Color.accentCyan.opacity(0.55), radius: 10)
                VStack(spacing: 4) {
                    Text(formatMMSS(remaining)).numStyle(size: 44)
                        .foregroundStyle(Theme.Color.fg)
                    Text("剩余").eyebrowStyle()
                }
            }
            .frame(width: 170, height: 170)
        }
    }

    private func pillButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(label).font(Theme.Font.body(size: 12, weight: .medium))
            }
            .foregroundStyle(Theme.Color.fg2)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.Color.surface, in: Capsule())
            .overlay(Capsule().stroke(Theme.Color.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func actionButton(_ title: String, emphasized: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Font.body(size: 15, weight: .semibold))
                .foregroundStyle(emphasized ? Theme.Color.bg : Theme.Color.fg)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(emphasized ? Theme.Color.accentCyan : Theme.Color.surface,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .stroke(emphasized ? .clear : Theme.Color.border, lineWidth: 1)
                )
                .modifier(EmphasizedGlow(emphasized: emphasized))
        }
        .buttonStyle(.plain)
    }

    private struct EmphasizedGlow: ViewModifier {
        let emphasized: Bool
        func body(content: Content) -> some View {
            if emphasized {
                content.neonGlow(.cyan, intensity: .sm, cornerRadius: Theme.Radius.md)
            } else {
                content
            }
        }
    }
}

/// 格式化 `MM:SS`，负数与 0 都显示 `0:00`。
func formatMMSS(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded()))
    return String(format: "%d:%02d", total / 60, total % 60)
}
