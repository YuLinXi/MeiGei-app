import SwiftUI
import UIKit

/// 休息计时 · 全屏弹窗（严格对齐原型 `dontlift-c-rest-timer.html`，整体放大并垂直居中）。
///
/// 由 `WorkoutSessionView` 通过 `if isRestExpanded` 条件渲染，ZStack overlay 在训练页之上；
/// 展开时上层会隐藏标题栏/Tab Bar 形成真全屏。磨砂遮罩虚化下方训练页但不离场，
/// 点击空白不关闭，必须点「最小化」回到 FAB。开/关均为渐显/渐隐。
/// 结构（自上而下，主簇垂直居中）：脉冲点 + 「组间休息 · REST」eyebrow → 大圆环
/// （墙钟驱动消耗式红弧 + 读数 + 总时长 + 下一组预告）→ 调时三件套（−10s / 完成 ✓ / +10s，无文案）
/// → 底部 pill（震动开关 / 最小化，常驻底部）。
struct RestTimerSheet: View {
    let controller: RestTimerController
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    /// 整体放大系数（原型按 320pt 窄屏标注，真机更宽，放大后接近原型占屏比并更聚焦）。
    private let k: CGFloat = 1.2

    var body: some View {
        ZStack {
            // 磨砂遮罩：material 模糊下层训练页 + 0.72 纸白底轻染（对齐原型 .scrim）。
            Theme.Color.bg.opacity(0.72)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
            content
        }
        .transition(.opacity)
    }

    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            eyebrow
            ring.padding(.top, 38 * k)
            controls.padding(.top, 42 * k)
            Spacer(minLength: 0)
            footer
        }
        .padding(.top, 16)
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
    }

    // MARK: - Eyebrow（脉冲点 + 组间休息 · REST）

    private var eyebrow: some View {
        HStack(spacing: 7 * k) {
            Circle()
                .fill(Theme.Color.accent)
                .frame(width: 7 * k, height: 7 * k)
                .opacity(reduceMotion ? 1 : (pulse ? 0.35 : 1))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.75).repeatForever(autoreverses: true), value: pulse)
            Text("组间休息 · REST")
                .font(Theme.Font.mono(size: 10 * k, weight: .bold))
                .tracking(0.2 * 10 * k)
                .textCase(.uppercase)
        }
        .foregroundStyle(Theme.Color.accent)
        .onAppear { pulse = true }
    }

    // MARK: - 圆环（墙钟驱动消耗式红弧 + 读数 + 下一组）

    private var ring: some View {
        // TimelineView 每秒驱动重绘，不靠手动 Timer（与 FAB 共享同一墙钟 endDate）。
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            let total = controller.totalDuration
            let remaining = controller.remaining
            let progress = total > 0 ? min(max(remaining / total, 0), 1) : 0
            ZStack {
                // 描边圆内缩 14×k：对齐原型 viewBox 236 / r 104（环中心线直径 208，四周留 14px），
                // 让中心读数相对环内径更饱满（与设计图一致），中心内容仍用整 236×k 框居中。
                ZStack {
                    Circle().stroke(Theme.Color.border, lineWidth: 9 * k)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Theme.Color.accent, style: StrokeStyle(lineWidth: 9 * k, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: Theme.Color.accent.opacity(0.25), radius: 8, x: 0, y: 3)
                        .animation(.linear(duration: 0.4), value: progress)
                }
                .padding(14 * k)
                VStack(spacing: 6 * k) {
                    Text(formatMMSS(remaining))
                        .numStyle(size: 56 * k, weight: .bold)
                        .foregroundStyle(Theme.Color.fg)
                    // 本次休息总时长（小一号，弱化）。
                    Text(formatMMSS(total))
                        .font(Theme.Font.mono(size: 12 * k, weight: .semibold))
                        .foregroundStyle(Theme.Color.fg2)
                    if let nextHint = controller.nextHint {
                        Text(.init(nextHint))
                            .font(Theme.Font.body(size: 12 * k))
                            .foregroundStyle(Theme.Color.fg2)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .frame(width: 236 * k, height: 236 * k)
        }
    }

    // MARK: - 调时三件套（−10s / 完成 ✓ / +10s，无文案）

    private var controls: some View {
        HStack(alignment: .center, spacing: 26 * k) {
            adjControl("−10s") { controller.adjust(by: -10) }
            doneControl
            adjControl("+10s") { controller.adjust(by: 10) }
        }
    }

    /// ±10s：白底 ghost 圆键。
    private func adjControl(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Font.mono(size: 12 * k, weight: .bold))
                .foregroundStyle(Theme.Color.fg)
                .frame(width: 54 * k, height: 54 * k)
                .background(Theme.Color.surface, in: Circle())
                .overlay(Circle().stroke(Theme.Color.border, lineWidth: 1))
                .shadow(color: Theme.Color.fg.opacity(0.07), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(PressableButtonStyle())
    }

    /// 完成：朱砂红实心圆 + 白色 ✓（与 set 完成勾同形同色），立即结束并收起。
    private var doneControl: some View {
        Button {
            if controller.hapticsEnabled { Theme.Haptics.notification(.success) }
            controller.stop()
            onDismiss()
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 28 * k, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 72 * k, height: 72 * k)
                .background(Theme.Color.accent, in: Circle())
                .shadow(color: Theme.Color.accent.opacity(0.35), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("完成休息")
    }

    // MARK: - 底部 pill（震动开关 / 最小化）

    private var footer: some View {
        HStack(spacing: 10) {
            // 震动：功能开关 + 持久化（控制前台结束/完成震动）。
            Button {
                controller.hapticsEnabled.toggle()
                if controller.hapticsEnabled { Theme.Haptics.impact(.light) }
            } label: {
                footPillLabel(icon: "iphone", text: "震动") {
                    toggleSwitch(on: controller.hapticsEnabled)
                }
            }
            .buttonStyle(PressableButtonStyle())

            // 最小化：收回 FAB。
            Button(action: onDismiss) {
                footPillLabel(icon: "arrow.down.right.and.arrow.up.left", text: "最小化") { EmptyView() }
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func footPillLabel<Trailing: View>(icon: String, text: String,
                                               @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold))
            Text(text).font(Theme.Font.body(size: 12, weight: .semibold))
            trailing()
        }
        .foregroundStyle(Theme.Color.fg2)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Theme.Color.surface, in: Capsule())
        .overlay(Capsule().stroke(Theme.Color.border, lineWidth: 1))
        .shadow(color: Theme.Color.fg.opacity(0.07), radius: 4, x: 0, y: 1)
    }

    /// 26×15 胶囊开关：开=朱砂红 + 白滑块靠右；关=灰底 + 白滑块靠左。
    private func toggleSwitch(on: Bool) -> some View {
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule().fill(on ? Theme.Color.accent : Theme.Color.border2)
            Circle().fill(.white).frame(width: 12, height: 12).padding(1.5)
        }
        .frame(width: 26, height: 15)
        .animation(.easeOut(duration: 0.18), value: on)
    }
}

/// 格式化 `MM:SS`（分钟也补零，对齐原型 `01:18`）；负数与 0 都显示 `00:00`。
func formatMMSS(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded()))
    return String(format: "%02d:%02d", total / 60, total % 60)
}
