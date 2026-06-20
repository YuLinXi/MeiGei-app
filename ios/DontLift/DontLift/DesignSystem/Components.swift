import SwiftUI
import UIKit

// MARK: - 圆形图标按钮（导航/菜单单一来源，36×36 白底 + border）

/// 圆形图标外观：白底 + border 描边 + 圆形；支持 `active` 高亮态与 `rotated` 旋转态。
/// 供点击版 `CircleIconButton` 与 Menu 版 `CircleIconMenu` 复用，确保两类入口像素一致。
/// 图标字号按直径 ×0.42 推导（36→≈15），调用点不再硬编码图标字号。
struct CircleIconLabel: View {
    let systemName: String
    var size: CGFloat = 36
    var active: Bool = false
    var rotated: Bool = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(active ? Theme.Color.accent : Theme.Color.fg)
            .rotationEffect(.degrees(rotated ? 90 : 0))
            .frame(width: size, height: size)
            .background(active ? Theme.Color.accentSoft : Theme.Color.surface, in: Circle())
            .overlay(Circle().stroke(active ? Theme.Color.accentSofter : Theme.Color.border, lineWidth: 1))
    }
}

/// 点击触发的圆形图标按钮（返回 / 次级图标动作）。默认直径 36。
struct CircleIconButton: View {
    let systemName: String
    var size: CGFloat = 36
    var active: Bool = false
    var rotated: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CircleIconLabel(systemName: systemName, size: size, active: active, rotated: rotated)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Menu 版圆形图标按钮（⋯ 更多操作）：与点击版同一外观，吸收原各页本地 `menuButton`。
struct CircleIconMenu<Content: View>: View {
    let systemName: String
    var size: CGFloat = 36
    var active: Bool = false
    var rotated: Bool = false
    @ViewBuilder var menu: () -> Content

    var body: some View {
        Menu {
            menu()
        } label: {
            CircleIconLabel(systemName: systemName, size: size, active: active, rotated: rotated)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - 子页统一 Header 容器

/// 子页（push/sheet 二级及以上）纸感导航栏内容：左返回 / 中标题 / 右操作三槽位，
/// 标题统一 `Theme.Font.l2`；iOS 26 双环处理集中收口在此。Tab 根页大标题范式不走此容器。
struct PaperToolbarContent<Trailing: View>: ToolbarContent {
    let title: String
    let onBack: () -> Void
    @ViewBuilder let trailing: () -> Trailing

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        // iOS 26 会给工具栏按钮自动套一层 Liquid Glass 圆形背景，与自绘纸感圆叠成「双环」；
        // 用 sharedBackgroundVisibility(.hidden) 关掉系统背景，仅保留我们的圆。
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarLeading) {
                CircleIconButton(systemName: "chevron.left", action: onBack)
            }
            .sharedBackgroundVisibility(.hidden)
            if !title.isEmpty {
                ToolbarItem(placement: .principal) { titleText }
            }
            ToolbarItem(placement: .topBarTrailing) { trailing() }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) {
                CircleIconButton(systemName: "chevron.left", action: onBack)
            }
            if !title.isEmpty {
                ToolbarItem(placement: .principal) { titleText }
            }
            ToolbarItem(placement: .topBarTrailing) { trailing() }
        }
    }

    private var titleText: some View {
        Text(title)
            .font(Theme.Font.l2)
            .foregroundStyle(Theme.Color.fg)
            .lineLimit(1)
    }
}

extension View {
    /// 子页统一导航栏：传入标题、返回回调与可选右侧操作（`CircleIconButton` 或 `CircleIconMenu`）。
    func paperToolbar<Trailing: View>(
        title: String = "",
        onBack: @escaping () -> Void,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            // 隐藏系统返回钮会连带禁用左边缘侧滑返回手势；在此单一收口处恢复，全 push 子页通吃。
            .background(SwipeBackEnabler())
            .toolbar { PaperToolbarContent(title: title, onBack: onBack, trailing: trailing) }
    }
}

// MARK: - 侧滑返回手势恢复

/// `interactivePopGestureRecognizer` 的接管 delegate（全局单例，长生命周期）。
/// `interactivePopGestureRecognizer.delegate` 为 weak，必须由长生命引用持有，否则手势行为回退。
/// 本工程是「全局唯一 NavigationStack 包 TabView」，全栈共享同一 `UINavigationController`，
/// 故单例持有其 weak 引用即可；`shouldBegin` 只依赖运行时 `viewControllers.count`，不缓存栈状态。
final class SwipeBackGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = SwipeBackGestureDelegate()
    weak var navigationController: UINavigationController?

    /// 根页保护：仅当栈深 > 1 时允许侧滑开始，避免 Tab 根页误触发 pop。
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        (navigationController?.viewControllers.count ?? 0) > 1
    }

    /// 允许与页面内部横滑控件（ScrollView / List / Swift Charts）并存——边缘手势仅占最左 ~20pt，互不抢占。
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}

/// 零尺寸、透明、不拦截触摸的隐形挂载点：探到所在 `UINavigationController`，
/// 把 `interactivePopGestureRecognizer.delegate` 接管为 `SwipeBackGestureDelegate.shared`。
/// 接管幂等（指向同一逻辑），子页零改动即获侧滑返回。
struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SwipeBackProbeController { SwipeBackProbeController() }
    func updateUIViewController(_ uiViewController: SwipeBackProbeController, context: Context) {}
}

final class SwipeBackProbeController: UIViewController {
    override func loadView() {
        // 透明且不参与命中测试，纯探针，绝不覆盖或拦截页面内容。
        let v = UIView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        view = v
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        installSwipeBackGesture()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        installSwipeBackGesture()
    }

    private func installSwipeBackGesture() {
        // 首帧 navigationController 可能尚为 nil，async 兜底竞态。
        DispatchQueue.main.async { [weak self] in
            guard let nav = self?.navigationController else { return }
            SwipeBackGestureDelegate.shared.navigationController = nav
            nav.interactivePopGestureRecognizer?.delegate = SwipeBackGestureDelegate.shared
            nav.interactivePopGestureRecognizer?.isEnabled = true
        }
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
    /// - Parameters:
    ///   - secondaryTitle: 可选的次要动作（描边样式）。传入后按钮区改为「主（填充）/ 次（描边）」垂直堆叠。
    ///   - onSecondary: 次要动作回调。
    ///   - showCancel: 是否渲染独立「取消」按钮；为 false 时仅靠点蒙层取消（如训练冲突弹窗）。
    func paperConfirmDialog(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmTitle: String,
        destructive: Bool = true,
        secondaryTitle: String? = nil,
        onSecondary: (() -> Void)? = nil,
        showCancel: Bool = true,
        onConfirm: @escaping () -> Void
    ) -> some View {
        fullScreenCover(isPresented: isPresented) {
            PaperConfirmDialog(isPresented: isPresented, title: title, message: message,
                               confirmTitle: confirmTitle, destructive: destructive,
                               secondaryTitle: secondaryTitle, onSecondary: onSecondary,
                               showCancel: showCancel, onConfirm: onConfirm)
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
    var secondaryTitle: String? = nil
    var onSecondary: (() -> Void)? = nil
    var showCancel: Bool = true
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
            buttons
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .shadow(color: Theme.Color.fg.opacity(0.18), radius: 32, x: 0, y: 12)
        .padding(.horizontal, 40)
    }

    /// 有 `secondaryTitle` 时：主（填充）/ 次（描边）/ [取消] 垂直堆叠；否则保持「取消 | 确认」横排。
    @ViewBuilder private var buttons: some View {
        if let secondaryTitle {
            VStack(spacing: Theme.Spacing.md) {
                filledButton(confirmTitle) { close { onConfirm() } }
                outlinedButton(secondaryTitle) { close { onSecondary?() } }
                if showCancel { cancelButton }
            }
        } else {
            HStack(spacing: Theme.Spacing.md) {
                if showCancel { cancelButton }
                filledButton(confirmTitle) { close { onConfirm() } }
            }
        }
    }

    /// 朱砂红填充 + 白字（主操作）。
    private func filledButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Font.l2)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }.buttonStyle(PressableButtonStyle())
    }

    /// 白底 + 描边 + 深字（次要操作）。
    private func outlinedButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Font.l2)
                .foregroundStyle(Theme.Color.fg)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).strokeBorder(Theme.Color.border, lineWidth: 1))
        }.buttonStyle(PressableButtonStyle())
    }

    /// 暖底浅灰「取消」。
    private var cancelButton: some View {
        Button { close {} } label: {
            Text("取消")
                .font(Theme.Font.l2)
                .foregroundStyle(Theme.Color.fg)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(Theme.Color.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }.buttonStyle(PressableButtonStyle())
    }
}

