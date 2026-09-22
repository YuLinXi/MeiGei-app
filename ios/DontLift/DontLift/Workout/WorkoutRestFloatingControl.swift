import SwiftUI

/// 拖动位置、计时和键盘避让仅由浮层观察，不使动作列表逐帧更新。
struct WorkoutRestFloatingControl: View {
    @Environment(RestTimerController.self) private var restTimer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let keyboardLayout: WorkoutKeyboardLayout
    let reordering: Bool
    let canShowWorkoutAddBar: Bool
    let onOpen: () -> Void
    @State private var fabAnchor: CGPoint?
    @GestureState private var fabDrag: CGSize = .zero
    private var sheetAnim: Animation { .easeInOut(duration: reduceMotion ? 0.2 : 0.3) }

    var body: some View {
        Group {
            if restTimer.isRunning && !restTimer.isExpanded && !reordering {
                GeometryReader { geo in
                    ZStack { restFAB }
                        .frame(width: Self.fabRadius * 2, height: Self.fabRadius * 2)
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                        .position(fabPosition(in: geo))
                        // 键盘顶边变化时平滑被顶上去/落回（与键盘升降同一条弹簧）；拖动由手势驱动，不经此动画。
                        .animation(.spring(response: 0.45, dampingFraction: 0.92), value: keyboardLayout.keypadTopY)
                        .gesture(
                            // 单一手势同时承担拖动与点按：实时位移跟手，松手按位移阈值区分「点按展开 / 落定」。
                            DragGesture(minimumDistance: 0, coordinateSpace: .named("fabSpace"))
                                .updating($fabDrag) { value, state, _ in state = value.translation }
                                .onEnded { value in
                                    let dist = hypot(value.translation.width, value.translation.height)
                                    if dist < 10 {
                                        onOpen()
                                        withAnimation(sheetAnim) { restTimer.isExpanded = true }
                                    } else {
                                        let base = fabAnchor ?? fabDefault(in: geo)
                                        fabAnchor = clampedFabPoint(
                                            CGPoint(x: base.x + value.translation.width,
                                                    y: base.y + value.translation.height), in: geo)
                                    }
                                }
                        )
                        // 「减弱动态效果」开启时只淡入淡出，不做缩放入场。
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                }
                .coordinateSpace(name: "fabSpace")
            }
        }
    }

    // MARK: FAB

    /// FAB 半径（直径 58）。
    private static let fabRadius: CGFloat = 29

    /// 把落点钳制在屏幕内；只在键盘升起时上抬，底部工具栏交给用户自行避让。
    private func clampedFabPoint(_ p: CGPoint, in geo: GeometryProxy) -> CGPoint {
        let r = Self.fabRadius
        let margin: CGFloat = 12
        let minX = margin + r
        let maxX = max(minX, geo.size.width - margin - r)
        let minY = margin + r
        var maxY = geo.size.height - margin - r
        if keyboardLayout.keypadTopY > 0 {   // 键盘升起：FAB 底边须在键盘顶上方
            let keypadTopLocal = keyboardLayout.keypadTopY - geo.frame(in: .global).minY
            maxY = min(maxY, keypadTopLocal - margin - r)
        }
        maxY = max(minY, maxY)
        return CGPoint(x: min(max(p.x, minX), maxX), y: min(max(p.y, minY), maxY))
    }

    /// FAB 默认位置：右下角；底部添加栏可见时上移避让。
    private func fabDefault(in geo: GeometryProxy) -> CGPoint {
        let r = Self.fabRadius
        let bottomOffset: CGFloat = canShowWorkoutAddBar ? 112 : 28
        return CGPoint(x: geo.size.width - Theme.Spacing.lg - r,
                       y: geo.size.height - bottomOffset - r)
    }

    /// FAB 当前位置：锚点（或默认右下角）+ 实时拖动位移，统一过钳制（含键盘顶上界）。
    private func fabPosition(in geo: GeometryProxy) -> CGPoint {
        let base = fabAnchor ?? fabDefault(in: geo)
        let moved = CGPoint(x: base.x + fabDrag.width, y: base.y + fabDrag.height)
        return clampedFabPoint(moved, in: geo)
    }

    private var restFAB: some View {
        // 整块（圆底 + 计时文字）作为单一视图，由外层 .position 统一移动、拖动跟手不分层。
        // 点按/拖动由调用点的单一 DragGesture 承担，故此处不再用 Button。无进度环（已移除动画与环形 UI）。
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                let remaining = restTimer.remaining
                VStack(spacing: 0) {
                    // 主体：剩余倒计时。
                    Text("\(Int(remaining.rounded()))s")
                        .font(Theme.Font.number(size: 17, weight: .heavy))
                        .foregroundStyle(Theme.Color.accent)
                    // 底部小一号：本次休息总时长 MM:SS。
                    Text(formatMMSS(restTimer.totalDuration))
                        .font(Theme.Font.number(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.Color.fg2)
                }
                .frame(width: 58, height: 58)
                .background(Circle().fill(Theme.Color.surface))
                .overlay(Circle().stroke(Theme.Color.accent, lineWidth: 2))
                // box-shadow: 朱砂红辉光 22% + 中性 sh-md。
                .shadow(color: Theme.Color.accent.opacity(0.22), radius: 9, x: 0, y: 4)
                .shadow(color: Theme.Color.fg.opacity(Theme.ShadowLevel.md.opacity), radius: Theme.ShadowLevel.md.radius, x: 0, y: Theme.ShadowLevel.md.y)
            }
        .compositingGroup()
        // 整圆为命中区；VoiceOver 以按钮呈现，默认动作 = 展开休息弹窗。
        .contentShape(Circle())
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("休息计时，点按展开")
        .accessibilityAction {
            onOpen()
            withAnimation(sheetAnim) { restTimer.isExpanded = true }
        }
    }

}
