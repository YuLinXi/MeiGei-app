import SwiftUI

// MARK: - 圆形图标按钮（导航/菜单，38×38 白底 + border）

struct CircleIconButton: View {
    let systemName: String
    let action: () -> Void
    var size: CGFloat = 38

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
                .frame(width: size, height: size)
                .background(Theme.Color.surface, in: Circle())
                .overlay(Circle().stroke(Theme.Color.border, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - 圆形「添加」按钮（主操作，accent 朱砂红 + 白底 + border + sm 阴影，36×36）

/// 仅外观：朱砂红 plus 图标。供 Button 与 Menu 作为 label 复用，确保两类入口视觉一致。
struct CircleAddLabel: View {
    var body: some View {
        Image(systemName: "plus")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Theme.Color.accent)
            .frame(width: 36, height: 36)
            .background(Theme.Color.surface, in: Circle())
            .overlay(Circle().stroke(Theme.Color.border, lineWidth: 1))
            .shadow(color: Theme.Color.fg.opacity(Theme.ShadowLevel.sm.opacity),
                    radius: Theme.ShadowLevel.sm.radius, x: 0, y: Theme.ShadowLevel.sm.y)
    }
}

/// 点击触发 action 的圆形添加按钮（动作/计划等单一入口）。Team 用 Menu + CircleAddLabel。
struct CircleAddButton: View {
    let action: () -> Void
    var accessibilityLabel: String = "添加"
    var body: some View {
        Button(action: action) { CircleAddLabel() }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - 输入框纸感样式

extension View {
    /// 纸感输入框外观：白底 + border 描边 + r-md 圆角 + 内边距。配合 `TextField` 使用。
    func paperField() -> some View {
        self
            .font(Theme.Font.l2)
            .foregroundStyle(Theme.Color.fg)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .stroke(Theme.Color.border, lineWidth: 1)
            )
    }
}

// MARK: - 数值 Stepper（± 圆钮 + 中值，accent 描边）

struct PaperStepper: View {
    let value: Int
    let range: ClosedRange<Int>
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            stepButton("minus") { if value > range.lowerBound { onChange(value - 1) } }
            Text("\(value)")
                .font(Theme.Font.number(size: 17, weight: .bold))
                .foregroundStyle(Theme.Color.fg)
                .frame(minWidth: 36)
            stepButton("plus") { if value < range.upperBound { onChange(value + 1) } }
        }
    }

    private func stepButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.Color.accent)
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(Theme.Color.accentSofter, lineWidth: 1.5))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - 纸感居中确认弹窗（替代原生 confirmationDialog / alert）

extension View {
    /// 纸感二次确认弹窗：以 `fullScreenCover`（透明背景）呈现，层级在 TabView 之上，
    /// scrim 覆盖底部 Tab Bar 使其不可操作。暗 scrim + 居中白卡（标题 + 说明 + 取消/确认两键）。
    func paperConfirmDialog(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmTitle: String,
        destructive: Bool = true,
        onConfirm: @escaping () -> Void
    ) -> some View {
        fullScreenCover(isPresented: isPresented) {
            PaperConfirmDialog(isPresented: isPresented, title: title, message: message,
                               confirmTitle: confirmTitle, destructive: destructive, onConfirm: onConfirm)
                .presentationBackground(.clear)
        }
        // 关闭系统的下滑入场动画（仅在开关时生效，不影响其它动画）；改由内部 scrim/卡片淡入。
        .transaction(value: isPresented.wrappedValue) { $0.disablesAnimations = true }
    }
}

struct PaperConfirmDialog: View {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let confirmTitle: String
    var destructive: Bool = true
    let onConfirm: () -> Void

    /// 进出场都用淡入淡出（+ 轻微缩放）：fullScreenCover 自身瞬时呈现/移除，动画交给内部 `shown`。
    @State private var shown = false
    private let anim = Animation.easeInOut(duration: 0.4)

    var body: some View {
        ZStack {
            Theme.Color.fg.opacity(shown ? 0.32 : 0)
                .ignoresSafeArea()
                .onTapGesture { close {} }
            card
                .scaleEffect(shown ? 1 : 0.94)
                .opacity(shown ? 1 : 0)
        }
        .onAppear { withAnimation(anim) { shown = true } }
    }

    /// 先淡出，动画结束后再移除 cover 并执行后续动作（确认）。
    private func close(_ action: @escaping () -> Void) {
        withAnimation(anim) { shown = false } completion: {
            isPresented = false
            action()
        }
    }

    private var card: some View {
        VStack(spacing: Theme.Spacing.lg) {
            VStack(spacing: 8) {
                Text(title)
                    .font(Theme.Font.display(size: 20, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                Text(message)
                    .font(Theme.Font.l4)
                    .foregroundStyle(Theme.Color.muted)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: Theme.Spacing.md) {
                Button { close {} } label: {
                    Text("取消")
                        .font(Theme.Font.l2)
                        .foregroundStyle(Theme.Color.fg)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Theme.Color.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                }.buttonStyle(PressableButtonStyle())
                Button { close { onConfirm() } } label: {
                    Text(confirmTitle)
                        .font(Theme.Font.l2)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                }.buttonStyle(PressableButtonStyle())
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .shadow(color: Theme.Color.fg.opacity(0.18), radius: 32, x: 0, y: 12)
        .padding(.horizontal, 40)
    }
}

