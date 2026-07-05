import SwiftUI
import UIKit

// MARK: - 圆形图标按钮（导航/菜单单一来源，36×36 白底 + border）

/// 圆形图标外观：白底 + border 描边 + 圆形；支持 `active` 高亮态与 `rotated` 旋转态。
/// 供点击版 `CircleIconButton` 与动作菜单版 `CircleIconMenu` 复用，确保两类入口像素一致。
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

// MARK: - 纸感动作菜单（替代系统 Menu）

/// 纸感动作菜单项：仅描述动作语义，具体视觉由 `PaperActionMenu` 统一渲染。
struct PaperMenuItem: Identifiable {
    enum Role: Equatable {
        case normal
        case destructive
    }

    let id: String
    let title: String
    let systemImage: String
    var role: Role = .normal
    var isEnabled: Bool = true
    let action: () -> Void

    init(
        id: String? = nil,
        title: String,
        systemImage: String,
        role: Role = .normal,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.id = id ?? "\(title)-\(systemImage)"
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.isEnabled = isEnabled
        self.action = action
    }
}

private struct PaperActionMenuAnchorKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

private struct PaperActionMenuAnchorReader: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: PaperActionMenuAnchorKey.self,
                                   value: proxy.frame(in: .global))
        }
    }
}

/// 触发按钮 + 自绘纸感动作菜单。菜单用透明 `fullScreenCover` 承载，避免被 toolbar / TabBar 层级裁切。
enum PaperActionMenuPlacement {
    case automatic
    case above
    case below
}

struct PaperActionMenuButton<Label: View>: View {
    let items: [PaperMenuItem]
    var accessibilityLabel: String = "菜单"
    var placement: PaperActionMenuPlacement = .automatic
    private let label: (Bool) -> Label

    @State private var isPresented = false
    @State private var anchorFrame: CGRect = .zero

    init(
        items: [PaperMenuItem],
        accessibilityLabel: String = "菜单",
        placement: PaperActionMenuPlacement = .automatic,
        @ViewBuilder label: @escaping (Bool) -> Label
    ) {
        self.items = items
        self.accessibilityLabel = accessibilityLabel
        self.placement = placement
        self.label = label
    }

    var body: some View {
        Button {
            Theme.Haptics.selection()
            isPresented = true
        } label: {
            label(isPresented)
                .background(PaperActionMenuAnchorReader())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .onPreferenceChange(PaperActionMenuAnchorKey.self) { anchorFrame = $0 }
        .fullScreenCover(isPresented: $isPresented) {
            PaperActionMenuOverlay(isPresented: $isPresented,
                                   anchorFrame: anchorFrame,
                                   items: items,
                                   placement: placement)
                .ignoresSafeArea()
                .presentationBackground(.clear)
                .interactiveDismissDisabled()
        }
        .transaction(value: isPresented) { $0.disablesAnimations = true }
        .disabled(items.filter(\.isEnabled).isEmpty)
    }
}

private struct PaperActionMenuOverlay: View {
    @Binding var isPresented: Bool
    let anchorFrame: CGRect
    let items: [PaperMenuItem]
    let placement: PaperActionMenuPlacement

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private let menuWidth: CGFloat = 232
    private let rowHeight: CGFloat = PaperActionMenuMetrics.rowHeight
    private let edgePadding: CGFloat = 12
    /// 统一浮层锚定规范：菜单卡片与触发圆钮保持 8pt 垂直间距。
    private let anchorGap: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let safe = proxy.safeAreaInsets
            let width = min(menuWidth, max(0, size.width - safe.leading - safe.trailing - edgePadding * 2))
            let height = rowHeight * CGFloat(items.count) + CGFloat(max(0, items.count - 1))
            let origin = menuOrigin(container: size, safeArea: safe, menuSize: CGSize(width: width, height: height))

            ZStack(alignment: .topLeading) {
                Theme.Color.fg.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture { close() }

                PaperActionMenuCard(items: items) { item in
                    close(after: item.action)
                }
                .frame(width: width)
                .offset(x: origin.x, y: origin.y)
                .opacity(shown ? 1 : 0)
                .scaleEffect(reduceMotion ? 1 : (shown ? 1 : 0.98), anchor: .topTrailing)
                .offset(y: reduceMotion ? 0 : (shown ? 0 : -4))
            }
            .onAppear {
                withAnimation(animation) { shown = true }
            }
        }
        .background(Color.clear.ignoresSafeArea())
    }

    private var animation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .easeOut(duration: 0.16)
    }

    private func close(after action: (() -> Void)? = nil) {
        withAnimation(animation) { shown = false } completion: {
            isPresented = false
            guard let action else { return }
            DispatchQueue.main.async { action() }
        }
    }

    private func menuOrigin(container: CGSize, safeArea: EdgeInsets, menuSize: CGSize) -> CGPoint {
        let minX = safeArea.leading + edgePadding
        let maxX = container.width - safeArea.trailing - edgePadding - menuSize.width
        let proposedX = anchorFrame.maxX - menuSize.width
        let x = min(max(proposedX, minX), max(minX, maxX))

        let minY = safeArea.top + edgePadding
        let maxY = container.height - safeArea.bottom - edgePadding - menuSize.height
        let belowY = anchorFrame.maxY + anchorGap
        let aboveY = anchorFrame.minY - anchorGap - menuSize.height
        let proposedY: CGFloat
        switch placement {
        case .automatic:
            proposedY = belowY <= maxY ? belowY : aboveY
        case .above:
            proposedY = aboveY
        case .below:
            proposedY = belowY
        }
        let y = min(max(proposedY, minY), max(minY, maxY))

        return CGPoint(x: x, y: y)
    }
}

private struct PaperActionMenuCard: View {
    let items: [PaperMenuItem]
    let onSelect: (PaperMenuItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                PaperActionMenuRow(item: item) {
                    guard item.isEnabled else { return }
                    onSelect(item)
                }
                if index < items.count - 1 {
                    Rectangle()
                        .fill(Theme.Color.border)
                        .frame(height: 1)
                        .padding(.leading, PaperActionMenuMetrics.dividerLeading)
                }
            }
        }
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .stroke(Theme.Color.border, lineWidth: 1)
        )
        .paperShadow(.md, cornerRadius: Theme.Radius.lg)
    }
}

private enum PaperActionMenuMetrics {
    static let rowHeight: CGFloat = 52
    static let horizontalPadding: CGFloat = 14
    static let itemSpacing: CGFloat = 10
    static let iconSize: CGFloat = 15
    static let iconFrameWidth: CGFloat = 20
    static let dividerLeading: CGFloat = horizontalPadding + iconFrameWidth + itemSpacing

    static var titleFont: Font {
        Theme.Font.body(size: 14, weight: .semibold)
    }
}

private struct PaperActionMenuRow: View {
    let item: PaperMenuItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: PaperActionMenuMetrics.itemSpacing) {
                Image(systemName: item.systemImage)
                    .font(.system(size: PaperActionMenuMetrics.iconSize, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: PaperActionMenuMetrics.iconFrameWidth)
                Text(item.title)
                    .font(PaperActionMenuMetrics.titleFont)
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer(minLength: 0)
            }
            .frame(height: PaperActionMenuMetrics.rowHeight)
            .padding(.horizontal, PaperActionMenuMetrics.horizontalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!item.isEnabled)
        .accessibilityLabel(item.title)
    }

    private var textColor: Color {
        guard item.isEnabled else { return Theme.Color.muted }
        return item.role == .destructive ? Theme.Color.danger : Theme.Color.fg
    }

    private var iconColor: Color {
        guard item.isEnabled else { return Theme.Color.muted }
        return item.role == .destructive ? Theme.Color.danger : Theme.Color.accent
    }
}

/// 动作菜单版圆形图标按钮（⋯ 更多操作）：与点击版同一外观，不再包装系统 `Menu`。
struct CircleIconMenu: View {
    let systemName: String
    var size: CGFloat = 36
    var active: Bool = false
    var rotated: Bool = false
    let items: [PaperMenuItem]
    var accessibilityLabel: String = "更多操作"

    var body: some View {
        PaperActionMenuButton(items: items, accessibilityLabel: accessibilityLabel) { isPresented in
            CircleIconLabel(systemName: systemName,
                            size: size,
                            active: active || isPresented,
                            rotated: rotated || isPresented)
        }
    }
}

// MARK: - 子页统一 Header 容器

/// 子页（push/sheet 二级及以上）纸感导航栏内容：左返回 / 中标题 / 右操作三槽位，
/// 标题统一 `Theme.Font.l2`；iOS 26 双环处理集中收口在此。Tab 根页大标题范式不走此容器。
struct PaperToolbarContent<Leading: View, Trailing: View>: ToolbarContent {
    let title: String
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        // iOS 26 会给工具栏按钮自动套一层 Liquid Glass 圆形背景，与自绘纸感圆叠成「双环」；
        // 用 sharedBackgroundVisibility(.hidden) 关掉系统背景，仅保留我们的圆。
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarLeading) {
                leading()
            }
            .sharedBackgroundVisibility(.hidden)
            if !title.isEmpty {
                ToolbarItem(placement: .principal) { titleText }
            }
            ToolbarItem(placement: .topBarTrailing) { trailing() }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) {
                leading()
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
    /// 子页统一导航栏：可自定义左侧控件，右侧操作一般为 `CircleIconButton` 或 `CircleIconMenu`。
    func paperToolbar<Leading: View, Trailing: View>(
        title: String = "",
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            // 隐藏系统返回钮会连带禁用左边缘侧滑返回手势；在此单一收口处恢复，全 push 子页通吃。
            .background(SwipeBackEnabler())
            .toolbar {
                PaperToolbarContent(title: title, leading: leading, trailing: trailing)
            }
    }

    /// 子页统一导航栏：传入标题、返回回调与可选右侧操作（`CircleIconButton` 或 `CircleIconMenu`）。
    func paperToolbar<Trailing: View>(
        title: String = "",
        leadingSystemName: String = "chevron.left",
        onBack: @escaping () -> Void,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) -> some View {
        paperToolbar(title: title) {
            CircleIconButton(systemName: leadingSystemName, action: onBack)
        } trailing: {
            trailing()
        }
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

// MARK: - 圆形「添加」按钮（主操作，accent 朱砂红 + 白底 + border + sm 阴影，42×42）

/// 仅外观：朱砂红 plus 图标。供 Button 与纸感动作菜单作为 label 复用，确保两类入口视觉一致。
struct CircleAddLabel: View {
    var active: Bool = false

    var body: some View {
        Image(systemName: "plus")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Theme.Color.accent)
            .frame(width: 42, height: 42)
            .background(active ? Theme.Color.accentSoft : Theme.Color.surface, in: Circle())
            .overlay(Circle().stroke(active ? Theme.Color.accentSofter : Theme.Color.border, lineWidth: 1))
            .shadow(color: Theme.Color.fg.opacity(Theme.ShadowLevel.sm.opacity),
                    radius: Theme.ShadowLevel.sm.radius, x: 0, y: Theme.ShadowLevel.sm.y)
            .frame(width: 48, height: 48)
            .contentShape(Circle())
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

/// 动作菜单版圆形添加按钮：用于顶部 `+` 展开多个创建入口。
struct CircleAddMenu: View {
    let items: [PaperMenuItem]
    var accessibilityLabel: String = "添加"

    var body: some View {
        PaperActionMenuButton(items: items, accessibilityLabel: accessibilityLabel) { isPresented in
            CircleAddLabel(active: isPresented)
        }
    }
}

// MARK: - Sheet 顶部栏

/// 底部 sheet 无操作标题栏：仅居中标题，不展示取消/完成按钮。
/// 用于只读详情、浏览型选择器等不需要显式确认的弹层；关闭依赖系统下滑。
struct PaperSheetTitleHeader: View {
    let title: String
    var topPadding: CGFloat = 16
    var bottomPadding: CGFloat = 12
    var background: Color = Theme.Color.surface
    var showsDivider: Bool = true

    var body: some View {
        Text(title)
            .font(Theme.Font.display(size: 21, weight: .heavy))
            .foregroundStyle(Theme.Color.fg)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity)
            .frame(height: PaperSheetHeaderActionButton.height)
            .padding(.horizontal, 18)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
            .background(background)
            .overlay(alignment: .bottom) {
                if showsDivider {
                    Rectangle().fill(Theme.Color.border).frame(height: 1)
                }
            }
    }
}

/// 底部 sheet 顶部栏：左取消 / 中标题 / 右确认，动作按钮统一为 44pt 胶囊触控区。
/// 用于替代系统 toolbar 文本按钮，避免不同 sheet 间字号、背景和点击反馈漂移。
struct PaperSheetHeader: View {
    let title: String
    var cancelTitle: String? = "取消"
    var confirmTitle: String? = nil
    var confirmEnabled: Bool = true
    var showsHandle: Bool = false
    var topPadding: CGFloat = 16
    var bottomPadding: CGFloat = 12
    var background: Color = Theme.Color.surface
    var onCancel: (() -> Void)?
    var onConfirm: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            if showsHandle {
                PaperSheetHandle()
            }

            ZStack {
                Text(title)
                    .font(Theme.Font.body(size: 17, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                    .lineLimit(1)
                    .padding(.horizontal, 96)

                HStack {
                    if let cancelTitle, let onCancel {
                        PaperSheetHeaderActionButton(title: cancelTitle, role: .cancel, action: onCancel)
                    } else {
                        PaperSheetHeaderActionButton.placeholder
                    }

                    Spacer(minLength: 0)

                    if let confirmTitle, let onConfirm {
                        PaperSheetHeaderActionButton(
                            title: confirmTitle,
                            role: .confirm,
                            enabled: confirmEnabled,
                            action: onConfirm
                        )
                    } else {
                        PaperSheetHeaderActionButton.placeholder
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, showsHandle ? 0 : topPadding)
            .padding(.bottom, bottomPadding)
        }
        .background(background)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.Color.border).frame(height: 1)
        }
    }
}

struct PaperSheetHandle: View {
    var body: some View {
        Capsule()
            .fill(Theme.Color.border2)
            .frame(width: 38, height: 5)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
    }
}

struct PaperSheetHeaderActionButton: View {
    enum Role {
        case cancel
        case confirm
    }

    static let width: CGFloat = 74
    static let height: CGFloat = 44

    let title: String
    var role: Role
    var enabled: Bool = true
    let action: () -> Void

    static var placeholder: some View {
        Color.clear.frame(width: width, height: height)
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Font.body(size: 15, weight: .bold))
                .foregroundStyle(foreground)
                .frame(width: Self.width, height: Self.height)
                .background(backgroundFill, in: Capsule())
                .overlay(Capsule().strokeBorder(border, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!enabled)
    }

    private var foreground: Color {
        guard enabled else { return Theme.Color.muted }
        switch role {
        case .cancel: return Theme.Color.fg2
        case .confirm: return Theme.Color.accent
        }
    }

    private var backgroundFill: Color {
        guard enabled else { return Theme.Color.surface2.opacity(0.72) }
        switch role {
        case .cancel: return Theme.Color.surface2
        case .confirm: return Theme.Color.accentSoft
        }
    }

    private var border: Color {
        guard enabled else { return Theme.Color.border.opacity(0.7) }
        switch role {
        case .cancel: return Theme.Color.border
        case .confirm: return Theme.Color.accentSofter
        }
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

    /// 先淡出，再执行动作，最后移除 cover。
    /// 动作必须先于 `isPresented = false`，否则 optional 绑定会先清空待确认对象。
    private func close(_ action: @escaping () -> Void) {
        withAnimation(anim) { shown = false } completion: {
            PaperConfirmDialogLifecycle.confirm(action: action) {
                isPresented = false
            }
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

enum PaperConfirmDialogLifecycle {
    static func confirm(action: () -> Void, dismiss: () -> Void) {
        action()
        dismiss()
    }
}
