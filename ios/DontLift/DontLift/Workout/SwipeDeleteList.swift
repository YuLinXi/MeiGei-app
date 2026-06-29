import SwiftUI

// MARK: - 左滑删除列表（首页「本周训练」/ 计划详情「动作」共用）

/// 左滑展开的协调器：作为「同一时刻仅一张展开」的单一来源，并支撑「点击别处自动收回」。
/// 由页面持有（`@State private var swipe = SwipeRowCoordinator()`），传入 `SwipeDeleteList`，
/// 同时经 `.collapseSwipeOnTap(swipe)` 让整页空白点击都能收回。
@MainActor
@Observable
final class SwipeRowCoordinator {
    /// 当前左滑展开的行标识；nil = 全部收回。
    var openID: AnyHashable?
    /// 收回当前展开行（无展开时为空操作）。
    func collapseAll() { if openID != nil { openID = nil } }
}

extension View {
    /// 点击附着区域内任意空白即收回当前展开的左滑行。
    /// 用 `simultaneousGesture` 与子卡片的点击/拖动并存，不拦截点卡片与滚动。
    func collapseSwipeOnTap(_ coordinator: SwipeRowCoordinator) -> some View {
        simultaneousGesture(TapGesture().onEnded { coordinator.collapseAll() })
    }
}

/// 可左滑删除的卡片列表：调用方只提供数据、行内容与回调，容器内部完成逐行接线与单卡展开协调。
/// 仿 `ForEach(_:id:)` 取显式 id KeyPath，兼容 `Workout`(`\.localId`) 与 `PlanItem`(`\.itemId`)。
struct SwipeDeleteList<Data: RandomAccessCollection, ID: Hashable, Row: View>: View {
    let data: Data
    let id: KeyPath<Data.Element, ID>
    @Bindable var coordinator: SwipeRowCoordinator
    var spacing: CGFloat = Theme.Spacing.sm
    let onTap: (Data.Element) -> Void
    let onDelete: (Data.Element, CGRect) -> Void
    @ViewBuilder let row: (Data.Element) -> Row

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(data, id: id) { item in
                SwipeToDeleteCard(
                    onTap: { onTap(item) },
                    onDelete: { onDelete(item, $0) },
                    rowID: AnyHashable(item[keyPath: id]),
                    openID: $coordinator.openID
                ) { row(item) }
            }
        }
    }
}

/// 首页「本周训练」是 ScrollView 内的卡片栈而非 List，无法用 `.swipeActions`，
/// 故以轻量水平拖动手势实现左滑显露删除按钮；点击空白处收回，点击卡片走 onTap。
/// 计划详情页的动作行复用同一交互（均经 `SwipeDeleteList` 装配）。
/// 「同一时刻仅一张展开 + 点击别处收回」由 `openID` 单一来源协调：
/// 左滑展开时认领 openID=rowID；任一卡片观察到 openID 变成别人（或被置 nil）即自动收回。
struct SwipeToDeleteCard<Content: View>: View {
    var onTap: () -> Void
    /// 回传该行的全局坐标，供父视图把删除确认卡片定位于其正下方。
    var onDelete: (CGRect) -> Void
    /// 本卡片的稳定标识；与 openID 配合实现「同一时刻仅一张展开」。
    var rowID: AnyHashable
    /// 「当前展开卡片」单一来源（nil 表示全部收回）。
    var openID: Binding<AnyHashable?>
    @ViewBuilder var content: Content
    @State private var offset: CGFloat = 0
    /// 越阈触感去抖：仅在首次越过删除显露阈值时触发一次 selection。
    @State private var didReveal = false
    /// 本行在屏幕中的全局 frame，删除时随回调一并回传。
    /// 只在初次出现和左滑展开期间更新，避免纵向滚动时所有行逐帧写 @State。
    @State private var globalFrame: CGRect = .zero
    private let revealed: CGFloat = -76
    /// 显露 / 收回统一回弹，保证手感对称。
    private let snap: Animation = .spring(response: 0.3, dampingFraction: 0.8)

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive) {
                collapse()
                onDelete(globalFrame)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Theme.Color.danger, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
            .buttonStyle(.plain)
            .opacity(offset < -8 ? 1 : 0)
            .accessibilityHidden(offset > -8)

            // 主体保持普通 content，避免外层 Button 抢走行内拖拽 handle / 编辑按钮手势。
            content
                .contentShape(Rectangle())
                .onTapGesture {
                    if offset < 0 { collapse() }
                    else { onTap() }
                }
                .offset(x: offset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 16)
                        .onChanged { v in
                            guard isHorizontalSwipe(v.translation) else { return }
                            if v.translation.width < 0 { offset = max(v.translation.width, revealed) }
                            else if offset < 0 { offset = min(0, revealed + v.translation.width) }
                            // 越过显露阈值首次触发选择触感，回到阈值内复位去抖标记。
                            if offset <= -40, !didReveal { Theme.Haptics.selection(); didReveal = true }
                            if offset > -40 { didReveal = false }
                        }
                        .onEnded { v in
                            guard isHorizontalSwipe(v.translation) else { return }
                            if v.translation.width < -40 { reveal() } else { collapse() }
                        }
                )
                .accessibilityAddTraits(.isButton)
                // 左滑手势对 VoiceOver 不可达，提供等价删除自定义动作（走同一二次确认）。
                .accessibilityAction(named: "删除") { onDelete(globalFrame) }
        }
        // 仅在必要时记录本行的全局 frame（屏幕坐标系），供删除确认卡片定位于其正下方。
        .background(GeometryReader { g in
            let frame = g.frame(in: .global)
            Color.clear
                .onAppear { updateGlobalFrame(frame, force: true) }
                .onChange(of: offset < 0) { _, active in
                    if active { updateGlobalFrame(frame, force: true) }
                }
                .onChange(of: frame) { _, new in
                    updateGlobalFrame(new, force: false)
                }
        })
        // 别的卡片展开（openID 变成别人）或父视图点击别处置 nil 时，本卡片自动收回。
        .onChange(of: openID.wrappedValue) { _, newValue in
            guard newValue != rowID, offset < 0 else { return }
            withAnimation(snap) { offset = 0 }
            didReveal = false
        }
    }

    /// 展开：滑到显露位并认领「当前展开卡片」。
    private func reveal() {
        withAnimation(snap) { offset = revealed }
        openID.wrappedValue = rowID
    }

    /// 收回：滑回原位并让出 openID（仅当当前展开的是自己）。
    private func collapse() {
        withAnimation(snap) { offset = 0 }
        didReveal = false
        if openID.wrappedValue == rowID { openID.wrappedValue = nil }
    }

    /// 明确横向意图后才接管拖动，避免轻微横向抖动干扰 ScrollView 纵向滚动。
    private func isHorizontalSwipe(_ translation: CGSize) -> Bool {
        let width = abs(translation.width)
        let height = abs(translation.height)
        if offset < 0 {
            return width > 8 && width > height
        }
        return width > 18 && width > height * 1.25
    }

    private func updateGlobalFrame(_ frame: CGRect, force: Bool) {
        guard force || offset < 0 else { return }
        guard globalFrame != frame else { return }
        globalFrame = frame
    }
}
