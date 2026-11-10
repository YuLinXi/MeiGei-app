import SwiftUI
import UIKit

/// 组间休息计时浮层：全屏遮罩承接背景点击，计时内容以居中卡片展示。
///
/// 由根层 overlay 挂在训练页之上；收起只改变展示状态，不停止计时，回到训练页的 FAB。
/// 默认字号保留圆环与调时三键；辅助功能大字按分／秒、操作和设置纵排，内容可滚动。
/// 两种布局读取同一墙钟剩余时间、总时长与下一组提示。
struct RestTimerSheet: View {
    let controller: RestTimerController
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var pulse = false

    /// 整体放大系数（原型按 320pt 窄屏标注，真机更宽，放大后接近原型占屏比并更聚焦）。
    private let k: CGFloat = 1.2

    var body: some View {
        ZStack {
            dismissBackground
            ViewThatFits(in: .vertical) {
                content
                ScrollView {
                    content.padding(.vertical, 16)
                }
                .scrollBounceBehavior(.basedOnSize)
                .clipped()
            }
        }
        .transition(.opacity)
    }

    /// 卡片外的遮罩是独立命中区，点击后收起浮层但不影响计时。
    private var dismissBackground: some View {
        Button(action: onDismiss) {
            // 黑色遮罩：不做模糊，保留下层训练页状态，同时增强卡片对比度。
            Color.black.opacity(0.35)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("收起休息计时")
        .accessibilityHint("返回训练页面，计时继续")
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            ring.padding(.top, 34 * k)
            controls.padding(.top, 38 * k)
            footer.padding(.top, 32 * k)
        }
        .padding(.top, 18)
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
        .frame(maxWidth: 360)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Theme.Color.border, lineWidth: 1)
        }
        .shadow(color: Theme.Color.fg.opacity(0.12), radius: 24, x: 0, y: 10)
        .padding(.horizontal, 16)
    }

    // MARK: - 顶部标题与小化

    @ViewBuilder private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            HStack(alignment: .top, spacing: 8) {
                eyebrow.frame(maxWidth: .infinity, alignment: .leading)
                minimizeButton
            }
        } else {
            ZStack(alignment: .topTrailing) {
                eyebrow.frame(maxWidth: .infinity, minHeight: 44)
                minimizeButton.padding(.top, -4).padding(.trailing, -4)
            }
        }
    }

    private var minimizeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "arrow.down.right.and.arrow.up.left")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Color.fg2)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("最小化休息计时")
        .accessibilityHint("返回训练页面，计时继续")
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
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.Color.action)
        .onAppear { pulse = true }
    }

    // MARK: - 圆环（墙钟驱动消耗式红弧 + 读数 + 下一组）

    private var ring: some View {
        // TimelineView 每秒驱动重绘，不靠手动 Timer（与 FAB 共享同一墙钟 endDate）。
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            let total = controller.totalDuration
            let remaining = controller.remaining
            let progress = total > 0 ? min(max(remaining / total, 0), 1) : 0
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 8) {
                        timePart(Int(max(0, remaining.rounded())) / 60, unit: "分")
                        timePart(Int(max(0, remaining.rounded())) % 60, unit: "秒")
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("剩余休息时间")
                    .accessibilityValue(formatMMSS(remaining))
                    restDetails(total: total)
                    ProgressView(value: progress).tint(Theme.Color.action)
                        .accessibilityHidden(true)
                }
            } else {
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
                        .font(Theme.Font.timer)
                            .foregroundStyle(Theme.Color.fg)
                        restDetails(total: total)
                    }
                }
                .frame(width: 236 * k, height: 236 * k)
            }
        }
    }

    private func timePart(_ value: Int, unit: String) -> some View {
        VStack(spacing: 3) {
            Text(String(format: "%02d", value))
                .font(Theme.Font.timer)
                .foregroundStyle(Theme.Color.fg)
                .fixedSize()
            Text(unit).font(Theme.Font.body(size: 12 * k)).foregroundStyle(Theme.Color.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func restDetails(total: TimeInterval) -> some View {
        VStack(spacing: 6 * k) {
            Text(formatMMSS(total))
                .font(Theme.Font.mono(size: 12 * k, weight: .semibold))
                .foregroundStyle(Theme.Color.fg2)
                .accessibilityLabel("总休息时长")
                .accessibilityValue("\(Int(total.rounded()))")
                .accessibilityIdentifier("rest.total")
            if let nextHint = controller.nextHint {
                Text(.init(nextHint))
                    .font(Theme.Font.body(size: 12 * k))
                    .foregroundStyle(Theme.Color.fg2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 调时三件套（−10s / 完成 ✓ / +10s，无文案）

    private var controls: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 26 * k))
        return layout {
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
                .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 12 : 0)
                .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 12 : 0)
                .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 54 * k,
                       height: dynamicTypeSize.isAccessibilitySize ? nil : 54 * k)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, minHeight: 44)
                .background(Theme.Color.surface, in: Capsule())
                .overlay(Capsule().stroke(Theme.Color.border, lineWidth: 1))
                .shadow(color: Theme.Color.fg.opacity(0.07), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(title.hasPrefix("+") ? "增加10秒" : "减少10秒")
    }

    /// 完成：朱砂红实心圆 + 白色 ✓（与 set 完成勾同形同色），立即结束并收起。
    private var doneControl: some View {
        Button {
            if controller.hapticsEnabled { Theme.Haptics.notification(.success) }
            controller.completeEarly()
            onDismiss()
        } label: {
            if dynamicTypeSize.isAccessibilitySize {
                Label("完成休息", systemImage: "checkmark")
                    .font(Theme.Font.body(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Theme.Color.action, in: Capsule())
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 28 * k, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 72 * k, height: 72 * k)
                    .background(Theme.Color.action, in: Circle())
                    .shadow(color: Theme.Color.accent.opacity(0.35), radius: 10, x: 0, y: 6)
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("完成休息")
    }

    // MARK: - 底部 pill（图标开关）

    private var footer: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            // 震动：功能开关 + 持久化（控制前台结束/完成震动）。
            Button {
                controller.hapticsEnabled.toggle()
                if controller.hapticsEnabled { Theme.Haptics.impact(.light) }
            } label: {
                footPillLabel(icon: "iphone", title: "震动") {
                    toggleSwitch(on: controller.hapticsEnabled)
                }
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("休息震动")
            .accessibilityValue(controller.hapticsEnabled ? "开" : "关")

            // 声音：功能开关 + 持久化（控制前台结束提醒音，无视静音键）。
            Button {
                controller.soundEnabled.toggle()
                if controller.soundEnabled { Theme.Haptics.impact(.light) }
            } label: {
                footPillLabel(icon: "speaker.wave.2", title: "声音") {
                    toggleSwitch(on: controller.soundEnabled)
                }
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("休息声音")
            .accessibilityValue(controller.soundEnabled ? "开" : "关")

        }
    }

    private func footPillLabel<Trailing: View>(icon: String, title: String,
                                               @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold))
            if dynamicTypeSize.isAccessibilitySize {
                Text(title).font(Theme.Font.body(size: 12))
            }
            trailing()
        }
        .foregroundStyle(Theme.Color.fg2)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, minHeight: 44)
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
