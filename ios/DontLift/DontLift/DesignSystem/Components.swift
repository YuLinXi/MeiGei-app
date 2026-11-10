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
            .foregroundStyle(active ? Theme.Color.action : Theme.Color.fg)
            .rotationEffect(.degrees(rotated ? 90 : 0))
            .frame(width: size, height: size)
            .background(active ? Theme.Color.accentSoft : Theme.Color.surface, in: Circle())
            .overlay(Circle().stroke(active ? Theme.Color.accentSofter : Theme.Color.border, lineWidth: 1))
            .frame(width: max(44, size), height: max(44, size))
            .contentShape(Rectangle())
    }
}

/// 点击触发的圆形图标按钮（返回 / 次级图标动作）。默认直径 36。
struct CircleIconButton: View {
    let systemName: String
    var size: CGFloat = 36
    var active: Bool = false
    var rotated: Bool = false
    var accessibilityLabel: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CircleIconLabel(systemName: systemName, size: size, active: active, rotated: rotated)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(accessibilityLabel ?? defaultAccessibilityLabel)
    }

    private var defaultAccessibilityLabel: String {
        switch systemName {
        case "chevron.left": return "返回"
        case "chevron.right": return "下一页"
        case "chevron.down": return "收起"
        case "xmark": return "关闭"
        case "calendar": return "日历"
        case "ellipsis": return "更多操作"
        default: return systemName
        }
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var shown = false
    @State private var contentHeight: CGFloat = 0

    private let menuWidth: CGFloat = 232
    private let edgePadding: CGFloat = 12
    /// 统一浮层锚定规范：菜单卡片与触发圆钮保持 8pt 垂直间距。
    private let anchorGap: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let availableWidth = max(0, size.width - edgePadding * 2)
            let width = dynamicTypeSize.isAccessibilitySize ? availableWidth : min(menuWidth, availableWidth)
            let initialHeight = PaperActionMenuMetrics.rowHeight * CGFloat(items.count)
            let height = min(contentHeight > 0 ? contentHeight : initialHeight,
                             max(0, size.height - edgePadding * 2))
            let containerOrigin = proxy.frame(in: .global).origin
            let localAnchor = anchorFrame.offsetBy(dx: -containerOrigin.x, dy: -containerOrigin.y)
            let origin = menuOrigin(container: size, anchor: localAnchor, menuSize: CGSize(width: width, height: height))

            ZStack(alignment: .topLeading) {
                Theme.Color.fg.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .accessibilityLabel("关闭菜单")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { close() }

                ScrollView {
                    PaperActionMenuCard(items: items) { item in
                        close(after: item.action)
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                        contentHeight = $0
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .stroke(Theme.Color.border, lineWidth: 1)
                }
                .paperShadow(.md, cornerRadius: Theme.Radius.lg)
                .accessibilityIdentifier("paper.actionMenu")
                .offset(x: origin.x, y: origin.y)
                .opacity(shown && contentHeight > 0 ? 1 : 0)
                .scaleEffect(reduceMotion ? 1 : (shown ? 1 : 0.98), anchor: .topTrailing)
                .offset(y: reduceMotion ? 0 : (shown ? 0 : -4))
            }
            .onAppear {
                withAnimation(animation) { shown = true }
            }
            .accessibilityAction(.escape) { close() }
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

    private func menuOrigin(container: CGSize, anchor: CGRect, menuSize: CGSize) -> CGPoint {
        let minX = edgePadding
        let maxX = container.width - edgePadding - menuSize.width
        let proposedX = anchor.maxX - menuSize.width
        let x = min(max(proposedX, minX), max(minX, maxX))

        let minY = edgePadding
        let maxY = container.height - edgePadding - menuSize.height
        let belowY = anchor.maxY + anchorGap
        let aboveY = anchor.minY - anchorGap - menuSize.height
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
    }
}

private enum PaperActionMenuMetrics {
    static let rowHeight: CGFloat = 52
    static let horizontalPadding: CGFloat = 14
    static let itemSpacing: CGFloat = 10
    static let iconSize: CGFloat = 15
    static let iconFrameWidth: CGFloat = 20
    static let dividerLeading: CGFloat = horizontalPadding + iconFrameWidth + itemSpacing

    static var titleFont: Theme.Font.Token {
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
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
            .frame(minHeight: PaperActionMenuMetrics.rowHeight)
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
        return item.role == .destructive ? Theme.Color.danger : Theme.Color.action
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
            // 以纸感 leading 控件替换返回项，保留系统返回语义。
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
/// 每次从手势所属视图寻找导航栈，避免 sheet 内的 NavigationStack 覆盖外层栈引用。
final class SwipeBackGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = SwipeBackGestureDelegate()

    /// 根页保护：仅当栈深 > 1 时允许侧滑开始，避免 Tab 根页误触发 pop。
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        var responder: UIResponder? = gestureRecognizer.view
        while let current = responder {
            if let navigation = current as? UINavigationController {
                return navigation.viewControllers.count > 1
            }
            responder = current.next
        }
        return false
    }

    /// 边缘返回优先判定，避免同一次拖动结束后再触发页面按钮或列表行操作。
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
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
    private weak var observedNavigationItem: UINavigationItem?
    private var navigationItemObservation: NSKeyValueObservation?

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        installSwipeBackGesture()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        installSwipeBackGesture()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        navigationItemObservation?.invalidate()
        navigationItemObservation = nil
        observedNavigationItem = nil
    }

    private func installSwipeBackGesture() {
        // 首帧 navigationController 可能尚为 nil，async 兜底竞态。
        DispatchQueue.main.async { [weak self] in
            guard let self, let nav = navigationController else { return }
            if let item = parent?.navigationItem, observedNavigationItem !== item {
                navigationItemObservation?.invalidate()
                observedNavigationItem = item
                // SwiftUI 重新配置工具栏时，保持纸感 leading 替换而非补充系统返回项。
                navigationItemObservation = item.observe(\.leftItemsSupplementBackButton,
                                                         options: [.initial, .new]) { item, _ in
                    MainActor.assumeIsolated {
                        if item.leftItemsSupplementBackButton { item.leftItemsSupplementBackButton = false }
                    }
                }
            }
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
            .foregroundStyle(Theme.Color.action)
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
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .frame(minHeight: PaperSheetHeaderActionButton.height)
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

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    cancelAction(wrapping: false)
                    Spacer(minLength: 0)
                    headerTitle.fixedSize()
                    Spacer(minLength: 0)
                    confirmAction(wrapping: false)
                }
                VStack(spacing: Theme.Spacing.sm) {
                    headerTitle
                        .fixedSize(horizontal: false, vertical: true)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Theme.Spacing.sm) {
                            cancelAction(wrapping: false)
                            confirmAction(wrapping: false)
                        }
                        VStack(spacing: Theme.Spacing.sm) {
                            cancelAction(wrapping: true)
                            confirmAction(wrapping: true)
                        }
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 18)
            .padding(.top, showsHandle ? 0 : topPadding)
            .padding(.bottom, bottomPadding)
        }
        .background(background)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.Color.border).frame(height: 1)
        }
    }

    private var headerTitle: some View {
        Text(title)
            .font(Theme.Font.body(size: 17, weight: .bold))
            .foregroundStyle(Theme.Color.fg)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder private func cancelAction(wrapping: Bool) -> some View {
        if let cancelTitle, let onCancel {
            PaperSheetHeaderActionButton(title: cancelTitle, role: .cancel,
                                         allowsWrapping: wrapping, action: onCancel)
        } else if !wrapping {
            PaperSheetHeaderActionButton.placeholder
        }
    }

    @ViewBuilder private func confirmAction(wrapping: Bool) -> some View {
        if let confirmTitle, let onConfirm {
            PaperSheetHeaderActionButton(title: confirmTitle, role: .confirm, enabled: confirmEnabled,
                                         allowsWrapping: wrapping, action: onConfirm)
        } else if !wrapping {
            PaperSheetHeaderActionButton.placeholder
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
    static let height: CGFloat = 48

    let title: String
    var role: Role
    var enabled: Bool = true
    var allowsWrapping: Bool = true
    let action: () -> Void

    static var placeholder: some View {
        Color.clear.frame(width: width, height: height)
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Font.body(size: 15, weight: .bold))
                .foregroundStyle(foreground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: !allowsWrapping, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(minWidth: Self.width, minHeight: Self.height)
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
        case .confirm: return Theme.Color.action
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
                .foregroundStyle(Theme.Color.action)
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(Theme.Color.accentSofter, lineWidth: 1.5))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(icon == "minus" ? "减少" : "增加")
        .accessibilityValue("\(value)")
        .disabled(icon == "minus" ? value <= range.lowerBound : value >= range.upperBound)
    }
}

// MARK: - 纸感居中确认弹窗（替代原生 confirmationDialog / alert）

extension View {
    /// 纸感二次确认弹窗：以 `fullScreenCover`（透明背景）呈现，层级在 TabView 之上，
    /// scrim 覆盖底部 Tab Bar 使其不可操作。暗 scrim + 居中白卡（标题 + 说明 + 取消/确认两键）。
    /// - Parameters:
    ///   - secondaryTitle: 可选的次要动作（描边样式）。传入后按钮区改为「主（填充）/ 次（描边）」垂直堆叠。
    ///   - onSecondary: 次要动作回调。
    ///   - secondaryDestructive: 次要动作是否为破坏性操作。
    ///   - showCancel: 是否渲染独立「取消」按钮；为 false 时仍可点蒙层取消。
    ///   - onCancel: 取消时清理本次确认的暂存状态，不执行确认或次要动作。
    func paperConfirmDialog(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmTitle: String,
        destructive: Bool = true,
        secondaryTitle: String? = nil,
        onSecondary: (() -> Void)? = nil,
        secondaryDestructive: Bool = false,
        showCancel: Bool = true,
        onCancel: (() -> Void)? = nil,
        onConfirm: @escaping () -> Void
    ) -> some View {
        fullScreenCover(isPresented: isPresented) {
            PaperConfirmDialog(isPresented: isPresented, title: title, message: message,
                               confirmTitle: confirmTitle, destructive: destructive,
                               secondaryTitle: secondaryTitle, onSecondary: onSecondary,
                               secondaryDestructive: secondaryDestructive,
                               showCancel: showCancel, onCancel: onCancel, onConfirm: onConfirm)
                .presentationBackground(.clear)
        }
        // 关闭系统的下滑入场动画（仅在开关时生效，不影响其它动画）；改由内部 scrim/卡片淡入。
        .transaction(value: isPresented.wrappedValue) { $0.disablesAnimations = true }
    }

    func activeWorkoutConflictDialog(isPresented: Binding<Bool>,
                                     onContinue: @escaping () -> Void,
                                     onDiscard: @escaping () -> Void,
                                     onCancel: @escaping () -> Void) -> some View {
        paperConfirmDialog(isPresented: isPresented,
                           title: "已有进行中的训练",
                           message: "继续现有训练可保留已记录的内容。丢弃后将开始新的训练。",
                           confirmTitle: "继续训练", destructive: false,
                           secondaryTitle: "丢弃并开始新训练", onSecondary: onDiscard,
                           secondaryDestructive: true, onCancel: onCancel, onConfirm: onContinue)
    }
}

struct PaperConfirmDialog: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let confirmTitle: String
    var destructive: Bool = true
    var secondaryTitle: String? = nil
    var onSecondary: (() -> Void)? = nil
    var secondaryDestructive: Bool = false
    var showCancel: Bool = true
    var onCancel: (() -> Void)? = nil
    let onConfirm: () -> Void

    /// 进出场都用淡入淡出（+ 轻微缩放）：fullScreenCover 自身瞬时呈现/移除，动画交给内部 `shown`。
    @State private var shown = false
    private let anim = Animation.easeInOut(duration: 0.4)

    var body: some View {
        ZStack {
            Theme.Color.fg.opacity(shown ? 0.32 : 0)
                .ignoresSafeArea()
                .onTapGesture { close { onCancel?() } }
            ViewThatFits(in: .vertical) {
                card.fixedSize(horizontal: false, vertical: true)
                ScrollView { card }
                    .scrollBounceBehavior(.basedOnSize)
            }
                .scaleEffect(reduceMotion ? 1 : (shown ? 1 : 0.94))
                .opacity(shown ? 1 : 0)
        }
        .accessibilityAction(.escape) { close { onCancel?() } }
        .onAppear { withAnimation(anim) { shown = true } }
    }

    /// 先淡出，再执行动作，最后移除 cover。
    /// 动作必须先于 `isPresented = false`，否则 optional 绑定会先清空待确认对象。
    private func close(_ action: @escaping () -> Void) {
        guard shown else { return }
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
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(message)
                    .font(Theme.Font.l4)
                    .foregroundStyle(Theme.Color.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
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
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .frame(minHeight: 50)
                .background(Theme.Color.action, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .contentShape(Rectangle())
        }.buttonStyle(PressableButtonStyle())
    }

    /// 白底 + 描边 + 深字（次要操作）。
    private func outlinedButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(role: secondaryDestructive ? .destructive : nil, action: action) {
            Text(title)
                .font(Theme.Font.l2)
                .foregroundStyle(secondaryDestructive ? Theme.Color.danger : Theme.Color.fg)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .frame(minHeight: 50)
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(secondaryDestructive ? Theme.Color.danger : Theme.Color.border, lineWidth: 1))
                .contentShape(Rectangle())
        }.buttonStyle(PressableButtonStyle())
    }

    /// 暖底浅灰「取消」。
    private var cancelButton: some View {
        Button { close { onCancel?() } } label: {
            Text("取消")
                .font(Theme.Font.l2)
                .foregroundStyle(Theme.Color.fg)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .frame(minHeight: 50)
                .background(Theme.Color.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .contentShape(Rectangle())
        }.buttonStyle(PressableButtonStyle())
    }
}

enum PaperConfirmDialogLifecycle {
    static func confirm(action: () -> Void, dismiss: () -> Void) {
        action()
        dismiss()
    }
}
