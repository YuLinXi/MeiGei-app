import SwiftUI

// MARK: - LIVE 悬浮胶囊（设计稿 home-2）

/// 训练进行中的「LIVE 悬浮胶囊」（Now Playing 风格）。
///
/// 有活跃会话时浮于首页内容之上：白底胶囊 + 训练时长 +「进行中」状态，
/// 可在屏内自由拖拽，松手吸附左/右边缘；点击直达进行中页。无活跃会话时不挂载即隐藏。
///
/// 自身以 `GeometryReader` 取容器尺寸做边界夹取与吸附（左上角坐标 + `offset` 定位，
/// 比 `.position` 更稳，不会被父容器尺寸建议撑开），调用方只需 `.overlay { LiveSessionCapsule(...) }`。
struct LiveSessionCapsule: View {
    /// 会话名称（取 `Workout.title`），仅用于无障碍朗读。
    let title: String
    /// 训练计时起点；nil 表示会话已创建但尚未开始计时。
    let timerStartedAt: Date?
    /// 点击进入进行中页。
    var onTap: () -> Void

    /// 胶囊左上角（容器坐标）。nil = 尚未定位，按默认左下角落位。
    @State private var origin: CGPoint?
    /// 拖拽起点（拖拽期间锁定的基准左上角）。
    @State private var dragBase: CGPoint?
    /// 拖拽中（用于按压缩放反馈）。
    @State private var dragging = false
    /// 实测胶囊尺寸，用于边界夹取与吸附。
    @State private var size: CGSize = .init(width: 74, height: 48)

    /// 左右贴边留白。
    private let edgeInset: CGFloat = 14
    /// 顶部避让大标题。
    private let topInset: CGFloat = 8
    /// 底部避让悬浮 CTA。
    private let bottomInset: CGFloat = 96
    /// 判定「点击 vs 拖拽」的位移阈值。
    private let tapSlop: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            // GeometryReader 默认把子视图布局在左上角，配合 offset 即为绝对定位。
            let o = resolved(in: geo.size)
            capsule
                .offset(x: o.x, y: o.y)
                .gesture(drag(in: geo.size))
        }
    }

    // MARK: 视觉

    private var capsule: some View {
        HStack(spacing: 8) {
            VStack(spacing: 2) {
                TimelineView(.periodic(from: .now, by: 1.0)) { ctx in
                    Text(formatElapsed(at: ctx.date))
                        .font(Theme.Font.number(size: 14, weight: .bold))
                        .foregroundStyle(Theme.Color.fg)
                        .monospacedDigit()
                }
                Text("进行中")
                    .font(Theme.Font.body(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Color.accent)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Color.muted)
        }
        .padding(.leading, 13)
        .padding(.trailing, 11)
        .frame(minWidth: 88, minHeight: 46)
        .fixedSize()
        .background(Theme.Color.surface, in: Capsule())
        .overlay(Capsule().stroke(Theme.Color.border, lineWidth: 1))
        .shadow(color: SwiftUI.Color.black.opacity(0.14), radius: 12, x: 0, y: 6)
        .scaleEffect(dragging ? 0.97 : 1)
        .animation(.easeOut(duration: 0.15), value: dragging)
        // 实测尺寸。
        .background(GeometryReader { p in
            SwiftUI.Color.clear
                .onAppear { size = p.size }
                .onChange(of: p.size) { _, new in size = new }
        })
        .contentShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("继续训练 \(title)，已进行 \(formatElapsed(at: .now))")
        .accessibilityAddTraits(.isButton)
    }

    private func formatElapsed(at date: Date) -> String {
        guard let timerStartedAt else { return "00:00" }
        let total = max(0, Int(date.timeIntervalSince(timerStartedAt)))
        if total >= 3600 {
            return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
        }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    // MARK: 手势

    private func drag(in container: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragBase == nil {
                    dragBase = resolved(in: container)
                    dragging = true
                }
                guard let base = dragBase else { return }
                origin = clamp(CGPoint(x: base.x + value.translation.width,
                                       y: base.y + value.translation.height),
                               in: container)
            }
            .onEnded { value in
                dragging = false
                defer { dragBase = nil }
                let moved = hypot(value.translation.width, value.translation.height)
                // 几乎未移动 → 视作点击。
                if moved < tapSlop {
                    Theme.Haptics.impact(.light)
                    onTap()
                    return
                }
                // 松手吸附最近的左/右边缘（按胶囊中心相对屏幕中线判定）。
                let current = origin ?? resolved(in: container)
                let centerX = current.x + size.width / 2
                let snappedLeft = centerX < container.width / 2
                    ? edgeInset
                    : container.width - edgeInset - size.width
                Theme.Haptics.selection()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    origin = clamp(CGPoint(x: snappedLeft, y: current.y), in: container)
                }
            }
    }

    // MARK: 定位

    /// 当前左上角：未定位时落在左下角默认位。
    private func resolved(in container: CGSize) -> CGPoint {
        if let origin { return clamp(origin, in: container) }
        return CGPoint(x: edgeInset,
                       y: container.height - bottomInset - size.height)
    }

    /// 把左上角夹取在容器可视区内（避让顶部大标题与底部 CTA）。
    private func clamp(_ p: CGPoint, in container: CGSize) -> CGPoint {
        let minX = edgeInset
        let maxX = max(minX, container.width - edgeInset - size.width)
        let minY = topInset
        let maxY = max(minY, container.height - bottomInset - size.height)
        return CGPoint(x: min(max(p.x, minX), maxX),
                       y: min(max(p.y, minY), maxY))
    }
}
