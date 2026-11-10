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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// 会话名称（取 `Workout.title`），仅用于无障碍朗读。
    let title: String
    /// 训练计时起点；nil 表示会话已创建但尚未开始计时。
    let timerStartedAt: Date?
    /// 下一组动作简讯。
    let nextSetBrief: String?
    /// 与容器同一坐标系的实测页面可用区域与主操作区域。
    let availableBounds: CGRect
    let exclusionFrames: [CGRect]
    let prefersCompact: Bool
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

    /// 判定「点击 vs 拖拽」的位移阈值。
    private let tapSlop: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            // GeometryReader 默认把子视图布局在左上角，配合 offset 即为绝对定位。
            let o = resolved(in: geo.size)
            TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                capsule(at: timeline.date)
            }
                .offset(x: o.x, y: o.y)
                .gesture(drag(in: geo.size))
        }
    }

    // MARK: 视觉

    private func capsule(at date: Date) -> some View {
        let brief = nextSetBriefText
        let compact = prefersCompact || (horizontalSizeClass == .compact && dynamicTypeSize.isAccessibilitySize)
        return HStack(spacing: 6) {
            if compact {
                Image("tabTrain")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Theme.Color.action)
            } else {
                VStack(alignment: brief == nil ? .center : .leading, spacing: 2) {
                    Text(formatElapsed(at: date))
                        .font(Theme.Font.number(size: 14, weight: .bold))
                        .foregroundStyle(Theme.Color.action)
                        .monospacedDigit()
                    Text(brief ?? "进行中")
                        .font(Theme.Font.body(size: 10, weight: .semibold))
                        .foregroundStyle(brief == nil ? Theme.Color.action : Theme.Color.fg)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: brief == nil ? nil : 108, alignment: .leading)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(brief == nil ? Theme.Color.action : Theme.Color.fg)
            }
        }
        .padding(.leading, compact ? 0 : 14)
        .padding(.trailing, compact ? 0 : 12)
        .padding(.vertical, compact ? 0 : 5)
        .frame(minWidth: compact ? 44 : 76, minHeight: 44)
        .fixedSize(horizontal: true, vertical: true)
        .background(Theme.Color.surface, in: Capsule())
        .overlay(Capsule().stroke(Theme.Color.border, lineWidth: 1))
        .shadow(color: SwiftUI.Color.black.opacity(0.14), radius: 12, x: 0, y: 6)
        .scaleEffect(reduceMotion ? 1 : (dragging ? 0.97 : 1))
        .opacity(reduceMotion && dragging ? 0.85 : 1)
        .animation(.easeOut(duration: 0.15), value: dragging)
        // 实测尺寸。
        .background(GeometryReader { p in
            SwiftUI.Color.clear
                .onAppear { if size != p.size { size = p.size } }
                .onChange(of: p.size) { _, new in if size != new { size = new } }
        })
        .contentShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(at: date))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            Theme.Haptics.impact(.light)
            onTap()
        }
    }

    private var nextSetBriefText: String? {
        guard let value = nextSetBrief?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }

    private func accessibilityText(at date: Date) -> String {
        let elapsed = formatElapsed(at: date)
        if let nextSetBriefText {
            return "继续训练 \(title)，已进行 \(elapsed)，下一组 \(nextSetBriefText)"
        }
        return "继续训练 \(title)，已进行 \(elapsed)"
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
                // 松手吸附可用区域的左右边缘，并按实际主操作重新避让。
                let current = origin ?? resolved(in: container)
                Theme.Haptics.selection()
                withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82)) {
                    origin = clamp(current, in: container, snapping: true)
                }
            }
    }

    // MARK: 定位

    /// 当前左上角：未定位时落在左下角默认位。
    private func resolved(in container: CGSize) -> CGPoint {
        placement(preferred: origin, in: container)
    }

    private func clamp(_ point: CGPoint, in container: CGSize, snapping: Bool = false) -> CGPoint {
        placement(preferred: point, in: container, snapping: snapping)
    }

    private func placement(preferred: CGPoint?, in container: CGSize, snapping: Bool = false) -> CGPoint {
        let bounds = CGRect(origin: .zero, size: container)
        let visible = availableBounds.intersection(bounds)
        return LiveCapsulePlacement.origin(preferred: preferred, size: size,
                                           available: visible.isNull || visible.isEmpty ? bounds : visible,
                                           exclusions: exclusionFrames, snapping: snapping)
    }
}
