import SwiftUI
import SwiftData
import Charts

// MARK: - 训练首页（设计稿 01）

/// 训练首页：本周 hero + 三宫格 + 最近训练列表 + 悬浮 CTA。
struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { $0.deletedAt == nil },
           sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]
    @Query(filter: #Predicate<WorkoutPlan> { $0.deletedAt == nil },
           sort: \WorkoutPlan.updatedAt, order: .reverse)
    private var plans: [WorkoutPlan]
    /// 导航打开的会话（点横幅继续 / 新建后进入 Live 记录界面）。
    @State private var openedSession: Workout?
    /// 单一活跃会话守卫：存在进行中会话时暂存「继续 / 丢弃」冲突态与待新建闭包。
    /// `showConflict` 仅驱动弹窗显隐，与数据分离——避免弹窗淡出关闭时清空 `conflict` 导致动作回调读到 nil。
    @State private var conflict: Workout?
    @State private var pendingBuild: (() -> Workout)?
    @State private var showConflict = false
    /// 待删除的已完成训练（左滑删除二次确认）。
    @State private var pendingDelete: Workout?
    /// 待删训练行的全局坐标，供删除确认卡片定位于其正下方。
    @State private var deleteRect: CGRect = .zero
    /// 左滑删除协调器：同一时刻仅一张展开，点击别处自动收回（详见 SwipeDeleteList）。
    @State private var swipe = SwipeRowCoordinator()

    /// 已完成训练（最近列表 / 统计仅看这些，进行中会话不混入）。
    private var finishedWorkouts: [Workout] { workouts.filter { $0.isFinished } }

    private var stats: WeeklyStats {
        WorkoutWeeklyStats.compute(workouts: finishedWorkouts)
    }
    /// 本周已完成训练（按 startedAt 落入本周）的次数。
    private var weeklyDoneCount: Int { stats.sessionCount }
    /// 本周训练命中 PR 的映射：workout.localId -> (动作名, 重量)。一周内只标第一项 PR。
    private var prByWorkout: [UUID: (name: String, weight: Double)] {
        // 历史训练按时间升序，逐次维护「每动作历史最大重量」，每当本次比历史大且为本周训练，则记一条。
        let asc = workouts.filter { $0.deletedAt == nil && $0.endedAt != nil }
            .sorted { $0.startedAt < $1.startedAt }
        var best: [String: Double] = [:]
        var out: [UUID: (String, Double)] = [:]
        for w in asc {
            var hit: (String, Double)?
            for ex in w.exercises {
                guard let m = ex.sets.compactMap(\.weightKg).max() else { continue }
                let prior = best[ex.historyKey]
                if prior == nil || m > prior! {
                    if hit == nil { hit = (ex.exerciseName, m) }
                    best[ex.historyKey] = m
                }
            }
            if let hit { out[w.localId] = hit }
        }
        return out
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Color.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                homeHeader
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        heroSection
                        statsGrid
                        recentSection
                        Color.clear.frame(height: 80) // 给底部 CTA 留位
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
                    // 点击列表任意其它区域（含列表下方空白）：收回当前展开的左滑卡片。
                    .collapseSwipeOnTap(swipe)
                }
            }
            startCTA
        }
        // 首页 Header 用自绘大标题（训练 + YU 头像，对齐设计图 .nav），隐藏系统导航栏。
        // 工具栏左右上角入口均已移除：右上角原「搜索占位 + 加号菜单」、左上角「日历 / 训练历史」
        // （历史模块已删，留待后续单独立项）。开始训练唯一收敛到底部悬浮 CTA。
        .toolbar(.hidden, for: .navigationBar)
        // 已完成训练 / 进行中会话 → 经 openedSession 绑定式导航到对应页面。
        .navigationDestination(item: $openedSession) { workoutDestination($0) }
        // 训练冲突二次确认：统一为纸感弹窗。无独立取消按钮，点蒙层即取消；
        // 「丢弃并开始新训练」为主（红填充）、「继续训练」为次（描边）。
        .paperConfirmDialog(
            isPresented: $showConflict,
            title: "已有进行中的训练",
            message: "同一时间只能有一个进行中的训练。继续既有训练，或丢弃后开始新的。",
            confirmTitle: "丢弃并开始新训练",
            secondaryTitle: "继续训练",
            onSecondary: {
                if let existing = conflict { openedSession = existing }
                clearConflict()
            },
            showCancel: false,
            onConfirm: {
                if let existing = conflict {
                    WorkoutSession.discard(existing, in: modelContext)
                    if let build = pendingBuild { commit(build) }
                }
                clearConflict()
            }
        )
        // 删除二次确认：以 fullScreenCover（透明背景）呈现，层级高于 TabView，scrim 覆盖底部 Tab Bar 使其不可点；
        // 卡片按被删 Item 的全局坐标定位于其正下方，点击卡片外的 scrim 即取消，不另设取消按钮。
        .fullScreenCover(isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } })) {
            if let w = pendingDelete {
                DeleteConfirmCover(
                    anchorRect: deleteRect,
                    onConfirm: {
                        Theme.Haptics.notification(.warning)
                        w.markDeleted()
                        try? modelContext.save()
                    },
                    onClose: { pendingDelete = nil }
                )
                .presentationBackground(.clear)
            }
        }
        // 关闭系统下滑入场动画（仅在开关时生效）；改由 DeleteConfirmCover 内部 scrim/卡片淡入。
        .transaction(value: pendingDelete != nil) { $0.disablesAnimations = true }
    }

    /// 导航目的地分流：已完成训练进只读日志详情，进行中会话进 Live 记录界面。
    @ViewBuilder
    private func workoutDestination(_ w: Workout) -> some View {
        if w.isFinished {
            WorkoutDetailView(workout: w)
        } else {
            WorkoutLoggingView(workout: w)
        }
    }

    // MARK: Header（设计图 .nav：大标题）

    /// 固定大标题 Header：左「训练」(36/800/-.03em)。
    private var homeHeader: some View {
        HStack {
            Text("训练")
                .font(Theme.Font.display(size: 36, weight: .heavy))
                .tracking(-1.08)
                .foregroundStyle(Theme.Color.fg)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    // MARK: Hero

    @ViewBuilder private var heroSection: some View {
        if weeklyDoneCount == 0 {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("THIS WEEK · 本周").eyebrowStyle()
                Text("准备好了吗？")
                    .font(Theme.Font.display(size: 32, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("本周还没开始 · 现在开始第 1 次训练")
                    .font(Theme.Font.body(size: 13))
                    .foregroundStyle(Theme.Color.fg2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        } else {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("THIS WEEK · 本周训练量").eyebrowStyle()
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(formatTons(stats.volumeKg)).numStyle(size: 56)
                            .foregroundStyle(Theme.Color.accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("t").numStyle(size: 22).foregroundStyle(Theme.Color.fg2)
                    }
                    Text("本周第 \(weeklyDoneCount) 次训练")
                        .font(Theme.Font.l4)
                        .foregroundStyle(Theme.Color.fg2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
                volumeSparkline
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }

    /// 近期每次训练训练量的迷你折线（Swift Charts），对齐设计稿 hero 右侧趋势图。
    @ViewBuilder private var volumeSparkline: some View {
        let series: [(idx: Int, vol: Double)] = Array(finishedWorkouts.prefix(8))
            .reversed().enumerated().map { item in
                let vol = item.element.exercises
                    .flatMap(\.sets)
                    .reduce(0.0) { $0 + (($1.weightKg ?? 0) * Double($1.reps ?? 0)) }
                return (item.offset, vol)
            }
        if series.count >= 2 {
            Chart(series, id: \.idx) { point in
                LineMark(x: .value("序", point.idx), y: .value("量", point.vol))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Theme.Color.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                AreaMark(x: .value("序", point.idx), y: .value("量", point.vol))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Theme.Color.accentSoft)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(width: 88, height: 56)
        }
    }

    // MARK: 三宫格

    private var statsGrid: some View {
        HStack(spacing: 0) {
            statCell(label: "总组数", value: stats.setCount > 0 ? "\(stats.setCount)" : "—")
            divider
            statCell(label: "总次数", value: stats.repCount > 0 ? "\(stats.repCount)" : "—")
            divider
            statCell(label: "平均时长",
                     value: stats.avgDurationSec > 0 ? formatMinutes(stats.avgDurationSec) : "—")
        }
        .cardStyle(padding: 0)
        .frame(height: 88)
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).numStyle(size: 22).foregroundStyle(Theme.Color.fg)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).eyebrowStyle()
                .lineLimit(1).minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    private var divider: some View {
        Rectangle().fill(Theme.Color.border).frame(width: 1)
    }

    // MARK: 最近训练

    private var recentSection: some View {
        // 仅展示已完成训练，进行中会话由顶部横幅承载，不混入常规行。
        let recent = Array(finishedWorkouts.prefix(8))
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("RECENT · 最近训练").eyebrowStyle()
                Spacer()
            }
            if recent.isEmpty {
                Text("还没有训练记录")
                    .font(Theme.Font.body(size: 13))
                    .foregroundStyle(Theme.Color.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Theme.Spacing.md)
            } else {
                SwipeDeleteList(
                    data: recent,
                    id: \.localId,
                    coordinator: swipe,
                    onTap: { openedSession = $0 },
                    onDelete: { w, rect in
                        deleteRect = rect
                        pendingDelete = w
                    }
                ) { recentRow($0) }
            }
        }
    }

    private func recentRow(_ w: Workout) -> some View {
        let totalSets = w.exercises.reduce(0) { $0 + $1.sets.count }
        let durationMin: Int? = w.endedAt.map { Int($0.timeIntervalSince(w.timerStartedAt ?? w.startedAt) / 60) }
        let pr = prByWorkout[w.localId]
        let durText = durationMin.map { "，\($0) 分钟" } ?? ""
        let prText = pr.map { "，\($0.name) PR \(formatKg($0.weight)) 公斤" } ?? ""
        let a11yLabel = "\(w.title ?? "训练")，\(w.exercises.count) 个动作，\(totalSets) 组\(durText)\(prText)"
        return HStack(spacing: Theme.Spacing.md) {
            dateBlock(w.startedAt)
            VStack(alignment: .leading, spacing: 4) {
                Text(w.title ?? "训练")
                    .font(Theme.Font.body(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text("\(w.exercises.count) 动作 · \(totalSets) 组" + (durationMin.map { " · \($0)′" } ?? ""))
                    .font(Theme.Font.body(size: 12))
                    .foregroundStyle(Theme.Color.fg2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if let pr {
                    Text("▲ \(pr.name) PR \(formatKg(pr.weight))kg")
                        .font(Theme.Font.body(size: 11, weight: .medium))
                        .foregroundStyle(Theme.Color.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Color.muted)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
    }

    private func dateBlock(_ date: Date) -> some View {
        let cal = Calendar.current
        let day = cal.component(.day, from: date)
        let month = cal.component(.month, from: date)
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "EEE"
        let weekday = fmt.string(from: date)
        return VStack(spacing: 2) {
            Text(String(format: "%02d", day)).numStyle(size: 22).foregroundStyle(Theme.Color.fg)
            Text("\(month)月 · \(weekday)")
                .font(Theme.Font.mono(size: 9, weight: .medium))
                .foregroundStyle(Theme.Color.muted)
        }
        .frame(width: 56, height: 56)
        .background(Theme.Color.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(Theme.Color.border, lineWidth: 1))
    }

    // MARK: 悬浮 CTA

    /// 首页「进行中」计划：与「计划」页共用 `WorkoutPlan.active` 判定，供 CTA 智能单键上浮。
    private var activePlan: WorkoutPlan? {
        WorkoutPlan.active(in: plans, workouts: workouts)
    }

    /// CTA 文案：存在进行中计划 → 「从「X」开始」；否则按本周是否已训练给空白训练文案。
    private func ctaTitle(_ plan: WorkoutPlan?) -> String {
        if let plan { return "从「\(plan.name)」开始" }
        return weeklyDoneCount == 0 ? "开始第 1 次训练" : "开始今日训练"
    }

    private var startCTA: some View {
        // 智能单键：有进行中计划从该计划预填，否则空白训练；无长按、无备选菜单。
        let plan = activePlan
        return Button {
            if let plan { start(from: plan) } else { startBlank() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                Text(ctaTitle(plan))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .font(Theme.Font.body(size: 16, weight: .semibold))
            .foregroundStyle(Theme.Color.bg)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .paperShadow(.md, cornerRadius: Theme.Radius.md)
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, 16) // tab bar 之上留 16pt
    }

    // MARK: actions

    /// 单一活跃会话守卫：存在进行中会话时弹「继续 / 丢弃」，否则直接新建并进入。
    private func beginSession(_ build: @escaping () -> Workout) {
        if let existing = WorkoutSession.activeSession(in: modelContext) {
            pendingBuild = build
            conflict = existing
            showConflict = true
        } else {
            commit(build)
        }
    }

    /// 关闭冲突弹窗并清理冲突态（动作执行完或取消后调用）。
    private func clearConflict() {
        conflict = nil
        pendingBuild = nil
    }

    private func commit(_ build: () -> Workout) {
        let w = build()
        modelContext.insert(w)
        try? modelContext.save()
        openedSession = w
    }

    private func startBlank() {
        Theme.Haptics.impact(.medium)
        beginSession { Workout(title: "训练") }
    }

    private func start(from plan: WorkoutPlan) {
        Theme.Haptics.impact(.medium)
        beginSession {
            let w = Workout(planId: plan.localId, title: plan.name)
            for item in plan.items.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                let ex = WorkoutExercise(builtinExerciseCode: item.builtinExerciseCode,
                                         customExerciseId: item.customExerciseId,
                                         exerciseName: item.exerciseName,
                                         primaryMuscle: nil, orderIndex: item.orderIndex)
                let count = max(item.suggestedSets ?? 1, 1)
                ex.sets = (0..<count).map { WorkoutSet(setIndex: $0, weightKg: nil, reps: item.suggestedReps) }
                w.exercises.append(ex)
            }
            return w
        }
    }
}

// MARK: - 左滑删除容器（非 List 卡片列表用，首页「最近训练」）

/// 删除二次确认浮层：透明 fullScreenCover 内的暗 scrim（盖住 Tab Bar）+ 锚定在被删 Item
/// 正下方的纸感卡片（单行删除文案，对齐计划页 ⋯ 菜单样式）。点击 scrim 即取消，不另设取消按钮。
struct DeleteConfirmCover: View {
    /// 被删行的全局 frame（屏幕坐标系）。
    let anchorRect: CGRect
    /// 确认卡的删除文案（首页为「删除训练」，计划详情为「删除动作」）。
    var confirmTitle: String = "删除训练"
    let onConfirm: () -> Void
    let onClose: () -> Void

    /// 进出场都用淡入淡出（+ 轻微缩放）：cover 自身瞬时呈现/移除，动画交给内部 `shown`。
    @State private var shown = false
    private let anim = Animation.easeInOut(duration: 0.25)
    private let cardWidth: CGFloat = 240

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Theme.Color.fg.opacity(shown ? 0.12 : 0)
                    .onTapGesture { close(nil) }
                card
                    .frame(width: cardWidth)
                    .offset(x: min(max(Theme.Spacing.lg, anchorRect.minX),
                                   proxy.size.width - cardWidth - Theme.Spacing.lg),
                            y: anchorRect.maxY + 8)
                    .scaleEffect(shown ? 1 : 0.96, anchor: .top)
                    .opacity(shown ? 1 : 0)
            }
        }
        // 让 GeometryReader 填满全屏，坐标原点对齐屏幕 (0,0)，与 anchorRect 的 .global 坐标一致。
        .ignoresSafeArea()
        .onAppear { withAnimation(anim) { shown = true } }
    }

    /// 先淡出，动画结束后再移除 cover；可选 action（确认）在移除前执行。
    private func close(_ action: (() -> Void)?) {
        withAnimation(anim) { shown = false } completion: {
            action?()
            onClose()
        }
    }

    private var card: some View {
        Button { close(onConfirm) } label: {
            HStack(spacing: 10) {
                Image(systemName: "trash").font(.system(size: 15, weight: .semibold))
                Text(confirmTitle).font(Theme.Font.l2)
                Spacer()
            }
            .foregroundStyle(Theme.Color.accent)
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .stroke(Theme.Color.border, lineWidth: 1)
        )
        .shadow(color: Theme.Color.fg.opacity(0.14), radius: 24, x: 0, y: 10)
    }
}

// MARK: - Format helpers

/// 训练量大数字：≥1t 取 1 位小数（28.4t），<1t 取 1 位小数（0.6t）。
func formatTons(_ kg: Double) -> String {
    let t = kg / 1000.0
    return String(format: "%.1f", t)
}

/// 平均时长：>= 60s 取分钟，否则 0′。
func formatMinutes(_ seconds: Double) -> String {
    let m = Int(seconds / 60)
    return "\(m)′"
}

// MARK: - 训练进行中（设计稿 02）

/// 训练录入的焦点单元：某组的重量或次数（按 `WorkoutSet.localId`）。
/// 单一真相源：`nil` ⟺ 自研键盘收起；非 `nil` ⟺ 键盘升起、所在组高亮。
enum FocusedCell: Equatable {
    case weight(UUID)
    case reps(UUID)

    var setId: UUID {
        switch self {
        case .weight(let id), .reps(let id): return id
        }
    }
    var isWeight: Bool { if case .weight = self { return true } else { return false } }
}

/// 组内可聚焦字段。
enum SetField { case weight, reps }

/// 训练进行中页（旧 WorkoutLoggingView 升级为新视觉，符号名保留以避免破坏 HistoryViews 等引用）。
struct WorkoutLoggingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TeamService.self) private var teamService
    @Environment(RestTimerController.self) private var restTimer
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(PRCelebrationCenter.self) private var prCelebration
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var workout: Workout
    @State private var pickingExercise = false
    /// 结束二次确认弹窗。
    @State private var confirmingFinish = false
    /// 手风琴互斥展开的三态：
    /// - `auto`：用户未交互，跟随默认计算值（第一个有未完成 set 的动作）；
    /// - `expanded(id)`：显式展开某动作；
    /// - `collapsedAll`：用户显式收起后全部折叠（不再回退默认，否则「收起默认项」会立刻被算回展开）。
    private enum AccordionState: Equatable {
        case auto
        case expanded(UUID)
        case collapsedAll
    }
    @State private var accordion: AccordionState = .auto
    /// 动作级组间休息时长（秒，0=关）；会话期内存，按 exercise.localId 键。
    @State private var restByExercise: [UUID: Int] = [:]
    /// 当前打开 ⋯ 菜单的动作 localId（nil = 无）。顶层浮层据 anchor 定位、外部点击关闭。
    @State private var menuExerciseId: UUID?
    /// 自研数字键盘的焦点单元（nil = 键盘收起）。
    @State private var focused: FocusedCell?
    /// 当前聚焦单元的编辑缓冲串（含 "0." / "72." 等中间态，聚焦单元据此显示）。
    @State private var buffer: String = ""
    /// 「打字即覆盖」标志：聚焦已有值后首个数字键清空重填。
    @State private var pendingReplace: Bool = false
    /// 各组行在屏幕(.global)坐标的 frame，用于判断聚焦组是否已在可视区内（避免无谓滚动）。
    @State private var setRowFrames: [UUID: CGRect] = [:]
    /// ScrollView 视口在 .global 坐标的 frame（顶边 = 可视区上界）。
    @State private var scrollViewport: CGRect = .zero
    /// 自研键盘顶边的 .global Y（0 = 键盘未显示/未测得）；作为可视区下界。
    @State private var keypadTopY: CGFloat = 0
    /// 休息悬浮按钮（FAB）拖动后的锚点（FAB 容器本地坐标，nil = 默认右下角）。
    @State private var fabAnchor: CGPoint?
    /// FAB 拖动中的实时位移（手势驱动，松手自动归零）；用 @GestureState 保证跟手不延迟。
    @GestureState private var fabDrag: CGSize = .zero

    /// 是否允许编辑内容（勾选完成 / 改重量次数 / 加删动作）：仅进行中会话可编辑；
    /// 已完成训练一律只读，产品逻辑不支持二次编辑。
    private var canEdit: Bool { workout.isActive }

    private var completedSetCount: Int {
        workout.exercises.flatMap(\.sets).filter(\.completed).count
    }

    private var remainingExerciseCount: Int {
        // 仍有未完成 set 的动作数。
        workout.exercises.filter { ex in ex.sets.contains { !$0.completed } }.count
    }

    private var currentVolume: Double {
        workout.exercises.flatMap(\.sets).reduce(0.0) { acc, s in
            guard s.completed else { return acc }
            return acc + (s.weightKg ?? 0) * Double(s.reps ?? 0)
        }
    }

    /// 休息弹窗开合动画：尊重「减弱动态效果」，开启时退化为短淡变而非弹簧。
    // 休息全屏弹窗开/关：渐显/渐隐（配合 RestTimerSheet 的 .opacity 过渡）。
    private var sheetAnim: Animation { .easeInOut(duration: reduceMotion ? 0.2 : 0.3) }

    /// 下一组提示：找第一个未完成 set 所属动作 + setIndex。
    /// PR 庆祝弹窗副标题：`title · N 动作 · N 组 · N 分钟`（title 为空则省略首段；
    /// 「组」用总 set 数，与训练列表口径一致；「分钟」由 startedAt→endedAt 算）。
    private var prSummary: String {
        var parts: [String] = []
        if let t = workout.title, !t.isEmpty { parts.append(t) }
        parts.append("\(workout.exercises.count) 动作")
        parts.append("\(workout.exercises.reduce(0) { $0 + $1.sets.count }) 组")
        if let end = workout.endedAt {
            let from = workout.timerStartedAt ?? workout.startedAt
            parts.append("\(Int(end.timeIntervalSince(from) / 60)) 分钟")
        }
        return parts.joined(separator: " · ")
    }

    /// 下一组提示（对齐原型文案「下一组 · **动作名** 第 N 组」，动作名用 markdown 加粗）。
    private var nextHint: String? {
        for ex in workout.exercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            if let next = ex.sets.sorted(by: { $0.setIndex < $1.setIndex })
                .first(where: { !$0.completed }) {
                return "下一组 · **\(ex.exerciseName)** 第 \(next.setIndex + 1) 组"
            }
        }
        return nil
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Theme.Color.bg.ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        LiveHeaderView(startedAt: workout.startedAt,
                                       timerStartedAt: workout.timerStartedAt,
                                       endedAt: workout.endedAt,
                                       onStart: { startTimerIfNeeded() },
                                       onFinish: { confirmingFinish = true })
                        triadStats
                        exerciseList
                        Color.clear.frame(height: 80)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.sm)
                    // 点击输入框外的空白区域：收起键盘（输入框/按钮的内层手势优先级更高，不受影响）。
                    .contentShape(Rectangle())
                    .onTapGesture { if focused != nil { dismissKeypad() } }
                }
                // 量取 ScrollView 视口（.global）：顶边作为可视区上界。
                .background(
                    GeometryReader { g in
                        Color.clear
                            .onChange(of: g.frame(in: .global)) { _, f in scrollViewport = f }
                            .onAppear { scrollViewport = g.frame(in: .global) }
                    }
                )
                // 聚焦单元变化时把所在组滚入键盘上方可视区；若已完整可见则不滚动。
                .onChange(of: focused) { _, new in
                    guard let id = new?.setId else { return }
                    if isRowFullyVisible(id) { return }
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
                // 自研数字键盘：仅当存在聚焦单元时从底部升起，并为内容预留底部安全区。
                .safeAreaInset(edge: .bottom) {
                    if focused != nil {
                        WorkoutKeypad(decimalEnabled: focused?.isWeight ?? false,
                                      onDigit: keypadDigit,
                                      onDot: keypadDot,
                                      onBackspace: keypadBackspace,
                                      onPrev: keypadPrev,
                                      onNext: keypadNext,
                                      onAddSet: keypadAddSet,
                                      onDismiss: dismissKeypad)
                            .background(
                                GeometryReader { g in
                                    Color.clear.preference(key: KeypadTopKey.self,
                                                           value: g.frame(in: .global).minY)
                                }
                            )
                            // 升降 transition 拆到 WorkoutKeypad 内部：收起按钮快速渐隐、面板下滑。
                    }
                }
                // preference 读取置于 safeAreaInset 之后：否则读不到键盘(外层 inset 内容)发出的 KeypadTopKey。
                .onPreferenceChange(SetRowFramesKey.self) { setRowFrames = $0 }
                .onPreferenceChange(KeypadTopKey.self) { keypadTopY = $0 }
            }
            // 浮动 FAB（rest 进行中且未展开即显示）：可在页面内自由拖动；键盘升起时被顶到键盘上方，
            // 不侵占键盘激活区。本屏无 Tab Bar，默认贴右下角。全屏休息弹窗已上提到全局 overlay。
            if restTimer.isRunning && !restTimer.isExpanded {
                GeometryReader { geo in
                    restFAB
                        .position(fabPosition(in: geo))
                        // 键盘顶边变化时平滑被顶上去/落回（与键盘升降同一条弹簧）；拖动由手势驱动，不经此动画。
                        .animation(.spring(response: 0.45, dampingFraction: 0.92), value: keypadTopY)
                        .gesture(
                            // 单一手势同时承担拖动与点按：实时位移跟手，松手按位移阈值区分「点按展开 / 落定」。
                            DragGesture(minimumDistance: 0, coordinateSpace: .named("fabSpace"))
                                .updating($fabDrag) { value, state, _ in state = value.translation }
                                .onEnded { value in
                                    let dist = hypot(value.translation.width, value.translation.height)
                                    if dist < 10 {
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
        // 键盘升降统一用近临界阻尼弹簧：面板下滑 + inset 收起 + 上方内容回流 + FAB 共用一条曲线，贴近 iOS 原生键盘的平滑。
        .animation(.spring(response: 0.45, dampingFraction: 0.92), value: focused == nil)
        // 子页统一导航栏：仅圆形返回键（双环处理收口在 paperToolbar）。
        .paperToolbar(title: workout.isActive ? "记录中" : (workout.title ?? "训练"), onBack: { dismiss() })
        // 动作 ⋯ 组间休息菜单：顶层浮层，按 anchor 定位于 ⋯ 下方；外部点击关闭。
        .overlayPreferenceValue(ExerciseMenuAnchorKey.self) { anchor in
            if let id = menuExerciseId,
               let ex = workout.exercises.first(where: { $0.localId == id }),
               let anchor {
                GeometryReader { proxy in
                    let pt = proxy[anchor]
                    let menuWidth: CGFloat = 280
                    ZStack(alignment: .topLeading) {
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .onTapGesture { menuExerciseId = nil }
                        restMenuCard(for: ex)
                            .frame(width: menuWidth)
                            .offset(x: min(max(16, pt.x - menuWidth), proxy.size.width - menuWidth - 16),
                                    y: pt.y + 8)
                    }
                }
                .transition(.opacity)
            }
        }
        // 组间休息已移入每个动作卡右上 ⋯ 菜单（动作级设置）；已完成训练只读，导航栏不再挂编辑入口。
        .paperConfirmDialog(
            isPresented: $confirmingFinish,
            title: "结束训练?",
            message: "将归档本次训练并计算 PR",
            confirmTitle: "结束训练",
            onConfirm: { finish() }
        )
        .sheet(isPresented: $pickingExercise) {
            ExercisePickerView { pick in addExercise(pick) }
        }
    }

    // MARK: 三联数

    private var triadStats: some View {
        HStack(spacing: 0) {
            triadCell(value: "\(completedSetCount)", label: "已完成组")
            divider
            triadCell(value: "\(remainingExerciseCount)", label: "剩余动作")
            divider
            triadCell(value: formatVolume(currentVolume), label: "训练量 kg·rep")
        }
        .cardStyle(padding: 0)
        .frame(height: 76)
    }

    private func triadCell(value: String, label: String) -> some View {
        // 原型 stat3 .n = PingFang(sans) 800 墨黑（非朱砂红、非等宽）；.k = mono 小标签。
        VStack(spacing: 7) {
            Text(value)
                .font(Theme.Font.display(size: 23, weight: .heavy))
                .foregroundStyle(Theme.Color.fg)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label).eyebrowStyle()
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(Theme.Color.border).frame(width: 1)
    }

    private func formatVolume(_ v: Double) -> String {
        if v >= 1000 { return String(format: "%.1fk", v / 1000) }
        return String(format: "%.0f", v)
    }

    // MARK: 动作分组

    /// 手风琴默认展开项：第一个仍有未完成 set 的动作，否则第一个动作。
    private var defaultExpandedId: UUID? {
        let sorted = workout.exercises.sorted { $0.orderIndex < $1.orderIndex }
        return sorted.first(where: { ex in ex.sets.contains { !$0.completed } })?.localId
            ?? sorted.first?.localId
    }

    private var exerciseList: some View {
        let sorted = workout.exercises.sorted { $0.orderIndex < $1.orderIndex }
        let activeId: UUID?
        switch accordion {
        case .auto: activeId = defaultExpandedId
        case .expanded(let id): activeId = id
        case .collapsedAll: activeId = nil
        }
        return VStack(spacing: Theme.Spacing.md) {
            ForEach(sorted) { ex in
                ExerciseBlock(exercise: ex,
                              readOnly: !canEdit,
                              isExpanded: activeId == ex.localId,
                              isMenuOpen: menuExerciseId == ex.localId,
                              focused: focused,
                              editingText: buffer,
                              onFocus: focus,
                              onToggleExpand: {
                                  withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                      // 点已展开的项 → 全部折叠；点其它项 → 互斥展开它。
                                      accordion = (activeId == ex.localId) ? .collapsedAll : .expanded(ex.localId)
                                  }
                              },
                              onMoreTap: {
                                  menuExerciseId = (menuExerciseId == ex.localId) ? nil : ex.localId
                              },
                              onChange: touch,
                              onCompleteSet: {
                                  // 完成第一组即自动启动训练计时（幂等：已启动则不动）。
                                  startTimerIfNeeded()
                                  let secs = restByExercise[ex.localId] ?? Int(restTimer.defaultDuration)
                                  if secs > 0 {
                                      restTimer.start(duration: TimeInterval(secs), label: ex.exerciseName)
                                      restTimer.nextHint = nextHint
                                  }
                              })
            }
            // 只读（已完成且未进入编辑态）时隐藏「添加动作」入口。
            if canEdit {
                Button { pickingExercise = true } label: {
                    Label("添加动作", systemImage: "plus")
                        .font(Theme.Font.body(size: 14, weight: .medium))
                        .foregroundStyle(Theme.Color.fg2)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .stroke(Theme.Color.border, style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )
                }.buttonStyle(.plain)
            }
        }
    }

    // MARK: 动作 ⋯ 组间休息菜单（顶层浮层，放大版）

    /// 组间休息分段可选值（关 / 60 / 90 / 120 / 180）。
    private static let restOptions: [Int] = [0, 60, 90, 120, 180]

    @ViewBuilder
    private func restMenuCard(for ex: WorkoutExercise) -> some View {
        let current = restByExercise[ex.localId] ?? Int(restTimer.defaultDuration)
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("组间休息").font(Theme.Font.l2).foregroundStyle(Theme.Color.fg)
                    Spacer()
                    Text(current == 0 ? "关" : "\(current)s")
                        .font(Theme.Font.mono(size: 15, weight: .bold))
                        .foregroundStyle(Theme.Color.accent)
                }
                HStack(spacing: 6) {
                    ForEach(Self.restOptions, id: \.self) { opt in
                        let on = current == opt
                        Button { restByExercise[ex.localId] = opt } label: {
                            Text(opt == 0 ? "关" : "\(opt)")
                                .font(Theme.Font.mono(size: 14, weight: .bold))
                                .foregroundStyle(on ? .white : Theme.Color.fg2)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(on ? Theme.Color.accent : Theme.Color.bg,
                                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .stroke(on ? Theme.Color.accent : Theme.Color.border, lineWidth: 1)
                                )
                        }.buttonStyle(.plain)
                    }
                }
                Text(current == 0 ? "该动作完成后不自动开始休息" : "该动作每组完成后统一休息 \(current) 秒")
                    .font(Theme.Font.l4).foregroundStyle(Theme.Color.muted)
            }
            .padding(16)
            Rectangle().fill(Theme.Color.border).frame(height: 1)
            Button { menuExerciseId = nil; delete(ex) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "trash").font(.system(size: 15, weight: .semibold))
                    Text("删除动作").font(Theme.Font.l2)
                    Spacer()
                }
                .foregroundStyle(Theme.Color.accent)
                .padding(.horizontal, 16).padding(.vertical, 14)
            }.buttonStyle(.plain)
        }
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .stroke(Theme.Color.border, lineWidth: 1)
        )
        .shadow(color: Theme.Color.fg.opacity(0.14), radius: 24, x: 0, y: 10)
    }

    // MARK: FAB

    /// FAB 半径（直径 58）。
    private static let fabRadius: CGFloat = 29

    /// 把落点钳制在安全区内：四周留边；键盘升起时下界抬到键盘顶之上，FAB 不侵占键盘激活区。
    private func clampedFabPoint(_ p: CGPoint, in geo: GeometryProxy) -> CGPoint {
        let r = Self.fabRadius
        let margin: CGFloat = 12
        let minX = margin + r
        let maxX = max(minX, geo.size.width - margin - r)
        let minY = margin + r
        var maxY = geo.size.height - margin - r
        if keypadTopY > 0 {   // 键盘升起：FAB 底边须在键盘顶上方
            let keypadTopLocal = keypadTopY - geo.frame(in: .global).minY
            maxY = min(maxY, keypadTopLocal - margin - r)
        }
        maxY = max(minY, maxY)
        return CGPoint(x: min(max(p.x, minX), maxX), y: min(max(p.y, minY), maxY))
    }

    /// FAB 默认位置：右下角（贴 lg 右距、28 下距）。
    private func fabDefault(in geo: GeometryProxy) -> CGPoint {
        let r = Self.fabRadius
        return CGPoint(x: geo.size.width - Theme.Spacing.lg - r,
                       y: geo.size.height - 28 - r)
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
        // 整圆为命中区；VoiceOver 以按钮呈现，默认动作 = 展开休息弹窗。
        .contentShape(Circle())
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("休息计时，点按展开")
        .accessibilityAction { withAnimation(sheetAnim) { restTimer.isExpanded = true } }
    }

    // MARK: actions

    private func addExercise(_ pick: ExercisePick) {
        let ex = WorkoutExercise(builtinExerciseCode: pick.builtinCode, customExerciseId: pick.customId,
                                 exerciseName: pick.name, primaryMuscle: pick.primaryMuscle,
                                 orderIndex: workout.exercises.count)
        ex.sets = [WorkoutSet(setIndex: 0)]
        workout.exercises.append(ex)
        touch()
    }

    private func delete(_ ex: WorkoutExercise) {
        workout.exercises.removeAll { $0.localId == ex.localId }
        modelContext.delete(ex)
        touch()
    }

    /// 启动训练计时（幂等）：仅在尚未启动时落定 timerStartedAt。
    /// 触发来源：完成第一组（自动）或顶部「开始训练」按钮（手动）。
    private func startTimerIfNeeded() {
        guard workout.timerStartedAt == nil else { return }
        workout.timerStartedAt = .now
        touch()
    }

    /// 结束训练（二次确认后调用）：置 endedAt + HealthKit 写入，再统一重算派生数据。
    private func finish() {
        Theme.Haptics.notification(.success)
        let endedAt = Date.now
        workout.endedAt = endedAt
        touch()
        // 时长以计时起点为基准（排除开始前空闲）；旧数据无 timerStartedAt 时回退 startedAt。
        let startedAt = workout.timerStartedAt ?? workout.startedAt
        Task { await healthKit.saveStrengthWorkout(start: startedAt, end: endedAt) }
        recomputeDerived()
    }

    /// 重算派生数据：PR 检测（命中弹庆祝）+ Team 打卡（按 localId 幂等：训练结束时首次创建摘要）。
    private func recomputeDerived() {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.deletedAt == nil && $0.endedAt != nil })
        if let all = try? modelContext.fetch(descriptor) {
            let history = all.filter { $0.localId != workout.localId }
            let prs = detectPersonalRecords(in: workout, history: history)
            // 庆祝弹窗经 App 级 center 由 MainTabView 呈现：结束训练会触发导航把本页换成
            // 只读详情页，若挂本页 sheet 会随本页销毁而一闪即逝（详见 PRCelebrationCenter）。
            if !prs.isEmpty { prCelebration.present(prs, summary: prSummary) }
        }
        let snapshot = workout
        Task { try? await teamService.checkIn(workout: snapshot) }
    }

    private func touch() {
        workout.markDirty()
        try? modelContext.save()
    }

    // MARK: 自研键盘 · 焦点与编辑

    /// 聚焦某单元：载入现值入缓冲并进入「打字即覆盖」。
    private func focus(_ cell: FocusedCell) {
        focused = cell
        buffer = currentText(for: cell)
        pendingReplace = true
    }

    private func dismissKeypad() {
        focused = nil
        buffer = ""
        pendingReplace = false
    }

    /// 目标组是否已完整落在「视口顶 ~ 键盘顶」之间（含少量余量）。
    /// 仅当键盘已显示且测得其顶边时才判定；否则返回 false（保持原有滚动行为，首次聚焦必滚）。
    private func isRowFullyVisible(_ id: UUID) -> Bool {
        guard keypadTopY > 0, !scrollViewport.isEmpty, let f = setRowFrames[id] else { return false }
        let pad: CGFloat = 8   // 余量：避免贴边时判为可见
        return f.minY >= scrollViewport.minY + pad && f.maxY <= keypadTopY - pad
    }

    /// 某单元当前模型值的显示串（重量走 formatKg，次数走整数串）。
    private func currentText(for cell: FocusedCell) -> String {
        guard let s = set(for: cell.setId) else { return "" }
        switch cell {
        case .weight: return s.weightKg.map { formatKg($0) } ?? ""
        case .reps:   return s.reps.map(String.init) ?? ""
        }
    }

    private func set(for id: UUID) -> WorkoutSet? {
        workout.exercises.flatMap(\.sets).first { $0.localId == id }
    }

    private func exercise(containing setId: UUID) -> WorkoutExercise? {
        workout.exercises.first { $0.sets.contains { $0.localId == setId } }
    }

    /// 当前动作的聚焦序列：组0.重量 → 组0.次数 → 组1.重量 → …
    private func sequence(for ex: WorkoutExercise) -> [FocusedCell] {
        ex.sets.sorted { $0.setIndex < $1.setIndex }
            .flatMap { [FocusedCell.weight($0.localId), FocusedCell.reps($0.localId)] }
    }

    // MARK: 自研键盘 · 按键

    private func keypadDigit(_ d: Int) {
        guard let cell = focused else { return }
        var b = pendingReplace ? "" : buffer
        pendingReplace = false
        if cell.isWeight {
            // 小数点后最多 2 位：超出则忽略本次按键。
            if let dot = b.firstIndex(of: ".") {
                let decimals = b.distance(from: b.index(after: dot), to: b.endIndex)
                if decimals >= 2 { return }
            } else if b.count >= 4 {
                // 整数部分上限 4 位（≤9999kg，防御性）。
                return
            }
        } else {
            // 次数：整数上限 4 位。
            if b.count >= 4 { return }
        }
        b += String(d)
        buffer = b
        writeBack()
    }

    private func keypadDot() {
        guard let cell = focused, cell.isWeight else { return }   // 次数态无效
        var b = pendingReplace ? "" : buffer
        pendingReplace = false
        guard !b.contains(".") else { return }                    // 单个小数点
        b = b.isEmpty ? "0." : b + "."                            // 空缓冲补 0.
        buffer = b
        writeBack()
    }

    private func keypadBackspace() {
        guard focused != nil else { return }
        pendingReplace = false
        if !buffer.isEmpty { buffer.removeLast() }
        writeBack()
    }

    /// 缓冲写回模型（空串→nil），并走即时落盘（markDirty + save）。
    private func writeBack() {
        guard let cell = focused, let s = set(for: cell.setId) else { return }
        switch cell {
        case .weight: s.weightKg = buffer.isEmpty ? nil : Double(buffer)
        case .reps:   s.reps = buffer.isEmpty ? nil : Int(buffer)
        }
        touch()
    }

    // MARK: 自研键盘 · 跳转

    private func keypadNext() {
        guard let cell = focused, let ex = exercise(containing: cell.setId) else { dismissKeypad(); return }
        let seq = sequence(for: ex)
        guard let idx = seq.firstIndex(of: cell) else { dismissKeypad(); return }
        if idx + 1 < seq.count { focus(seq[idx + 1]) } else { dismissKeypad() }  // 末项收起
    }

    private func keypadPrev() {
        guard let cell = focused, let ex = exercise(containing: cell.setId) else { return }
        let seq = sequence(for: ex)
        guard let idx = seq.firstIndex(of: cell), idx > 0 else { return }        // 首项保持
        focus(seq[idx - 1])
    }

    /// 「加一组」：在当前聚焦组所属动作追加一组（预填上一组重量），并聚焦其重量。
    /// 与 ExerciseBlock.addSet 行为一致；高频操作不离键盘。
    private func keypadAddSet() {
        guard let cell = focused, let ex = exercise(containing: cell.setId) else { return }
        let next = (ex.sets.map(\.setIndex).max() ?? -1) + 1
        let lastWeight = ex.sets.sorted { $0.setIndex < $1.setIndex }.last?.weightKg
        let newSet = WorkoutSet(setIndex: next, weightKg: lastWeight)
        ex.sets.append(newSet)
        touch()
        focus(.weight(newSet.localId))
    }
}

// MARK: - LiveHeader: REC · MM:SS + 暂停/结束

private struct LiveHeaderView: View {
    /// 会话创建时刻，仅作旧数据/已结束时长的回退基准。
    let startedAt: Date
    /// nil = 计时未启动（显示「开始训练」）；非 nil = 计时已启动（REC 从此刻走表）。
    let timerStartedAt: Date?
    /// nil = 进行中；非 nil = 已完成（计时冻结为 endedAt − 计时起点）。
    let endedAt: Date?
    /// 手动启动计时（「开始训练」按钮）。
    let onStart: () -> Void
    let onFinish: () -> Void
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isEnded: Bool { endedAt != nil }
    /// 计时未启动且未结束：会话已创建、尚未开始计时。
    private var notStarted: Bool { timerStartedAt == nil && endedAt == nil }
    /// 已完成时长基准：优先计时起点，回退创建时刻（兼容旧数据）。
    private var endedBase: Date { timerStartedAt ?? startedAt }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            HStack(spacing: 8) {
                if isEnded {
                    // 已完成：静态时长，无录制点、不再增长。
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Color.accent)
                    Text("时长 · \(formatHMS(endedAt!.timeIntervalSince(endedBase)))")
                        .font(Theme.Font.number(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Color.fg)
                } else if notStarted {
                    // 未启动：灰点 + 静态 00:00，提示计时尚未开始。
                    Circle().fill(Theme.Color.muted)
                        .frame(width: 9, height: 9)
                    Text("未开始")
                        .font(Theme.Font.mono(size: 11, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(Theme.Color.muted)
                    Text(formatHMS(0))
                        .font(Theme.Font.number(size: 15, weight: .bold))
                        .foregroundStyle(Theme.Color.fg2)
                } else {
                    // 进行中：墙钟实时计时（含组间休息，无暂停）。朱砂红脉冲点 + REC + 等宽计时。
                    // 「减弱动态效果」开启时不做 repeatForever 脉冲，呈静态红点。
                    Circle().fill(Theme.Color.accent)
                        .frame(width: 9, height: 9)
                        .scaleEffect(reduceMotion ? 1.0 : (pulse ? 1.0 : 0.7))
                        .opacity(reduceMotion ? 1.0 : (pulse ? 1.0 : 0.6))
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.75).repeatForever(autoreverses: true), value: pulse)
                        .onAppear { if !reduceMotion { pulse = true } }
                    Text("REC")
                        .font(Theme.Font.mono(size: 11, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(Theme.Color.accent)
                    TimelineView(.periodic(from: .now, by: 1.0)) { ctx in
                        Text(formatHMS(ctx.date.timeIntervalSince(timerStartedAt ?? startedAt)))
                            .font(Theme.Font.number(size: 15, weight: .bold))
                            .foregroundStyle(Theme.Color.fg)
                    }
                }
            }
            Spacer()
            if isEnded {
                Text("已完成").font(Theme.Font.l4).foregroundStyle(Theme.Color.muted)
            } else if notStarted {
                // 未启动：朱砂红实心胶囊「开始训练」，点击手动启动计时（无二次确认）。
                Button(action: onStart) {
                    Text("开始训练")
                        .font(Theme.Font.body(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 32)
                        .background(Theme.Color.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("开始训练")
            } else {
                // 进行中仅有「停止训练」（朱砂红实心胶囊，全屏唯一此形态）。
                Button(action: onFinish) {
                    Text("停止训练")
                        .font(Theme.Font.body(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 32)
                        .background(Theme.Color.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("停止训练")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.Color.border, lineWidth: 1))
        .paperShadow(.sm, cornerRadius: Theme.Radius.md)
    }
}

private func formatHMS(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded()))
    return String(format: "%d:%02d", total / 60, total % 60)
}

// MARK: - 动作分组卡

/// 动作 ⋯ 按钮的位置锚点，供父视图顶层菜单浮层定位。
private struct ExerciseMenuAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGPoint>? = nil
    static func reduce(value: inout Anchor<CGPoint>?, nextValue: () -> Anchor<CGPoint>?) {
        value = nextValue() ?? value
    }
}

/// 各组行在 .global 坐标的 frame，按 set.localId 聚合冒泡到顶层，用于可视区判定。
private struct SetRowFramesKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// 自研键盘顶边的 .global Y，冒泡到顶层作可视区下界。
private struct KeypadTopKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next != 0 { value = next }
    }
}

private struct ExerciseBlock: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var exercise: WorkoutExercise
    /// 只读态（已完成且未进入编辑）：隐藏菜单、禁用组内操作。
    var readOnly: Bool = false
    /// 手风琴：是否展开 set 列表（false 时折叠为单行摘要）。
    var isExpanded: Bool = true
    /// ⋯ 组间休息菜单是否打开（菜单本体由父视图顶层浮层渲染）。
    var isMenuOpen: Bool = false
    /// 自研键盘焦点单元（父视图持有），用于派生编辑高亮与聚焦字段。
    var focused: FocusedCell? = nil
    /// 聚焦单元的编辑缓冲串（仅聚焦字段据此显示）。
    var editingText: String = ""
    /// 请求聚焦某单元。
    var onFocus: (FocusedCell) -> Void = { _ in }
    var onToggleExpand: () -> Void = {}
    var onMoreTap: () -> Void = {}
    let onChange: () -> Void
    let onCompleteSet: () -> Void

    private var sortedSets: [WorkoutSet] {
        exercise.sets.sorted { $0.setIndex < $1.setIndex }
    }
    private var activeSetIndex: Int? {
        sortedSets.first(where: { !$0.completed })?.setIndex
    }
    /// 该组当前被聚焦的字段（nil = 未聚焦本组）。
    private func focusedField(for set: WorkoutSet) -> SetField? {
        guard let f = focused, f.setId == set.localId else { return nil }
        return f.isWeight ? .weight : .reps
    }
    private var doneCount: Int { sortedSets.filter(\.completed).count }
    private var isAllDone: Bool {
        !sortedSets.isEmpty && sortedSets.allSatisfy(\.completed)
    }
    /// 折叠态摘要：未开始 · 计划 N 组 / N/总 组 / 已完成。
    private var summaryText: String {
        if isAllDone { return "已完成 · \(sortedSets.count) 组" }
        if doneCount == 0 { return "未开始 · 计划 \(sortedSets.count) 组" }
        return "\(doneCount)/\(sortedSets.count) 组"
    }

    var body: some View {
        VStack(spacing: 0) {
            head
            if isExpanded {
                Rectangle().fill(Theme.Color.border).frame(height: 1).padding(.horizontal, 15)
                VStack(spacing: 0) {
                    ForEach(sortedSets) { set in
                        SetRow(set: set,
                               // 键盘升起（任一组聚焦）时，待办弱提示让位给聚焦组，避免「双当前」。
                               isTodo: activeSetIndex == set.setIndex && focused == nil,
                               readOnly: readOnly,
                               focusedField: focusedField(for: set),
                               editingText: editingText,
                               onChange: onChange,
                               onComplete: onCompleteSet,
                               onFocus: { field in
                                   onFocus(field == .weight ? .weight(set.localId) : .reps(set.localId))
                               })
                        .id(set.localId)
                        // 上报本行 .global frame，供父视图判断聚焦组是否已在可视区内。
                        .background(
                            GeometryReader { g in
                                Color.clear.preference(key: SetRowFramesKey.self,
                                                       value: [set.localId: g.frame(in: .global)])
                            }
                        )
                    }
                }
                .padding(.top, 4).padding(.bottom, 8)
                if !readOnly { addSetButton }
            }
        }
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .stroke(isExpanded ? Theme.Color.border2 : Theme.Color.border, lineWidth: 1)
        )
        .paperShadow(.sm, cornerRadius: Theme.Radius.lg)
    }

    // 卡头：展开态 = 名称 + ⋯ + 收起 ^；折叠态 = 名称 + 摘要 + 展开 ⌄。
    private var head: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(exercise.exerciseName)
                .font(Theme.Font.l2)
                .foregroundStyle(isAllDone ? Theme.Color.muted : Theme.Color.fg)
            Spacer()
            if isExpanded {
                if !readOnly { moreButton }
                Image(systemName: "chevron.up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Color.muted)
            } else {
                Text(summaryText).font(Theme.Font.l4).foregroundStyle(Theme.Color.muted)
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Color.muted)
            }
        }
        .padding(.horizontal, 15)
        .frame(minHeight: isExpanded ? 48 : 50)
        .contentShape(Rectangle())
        .onTapGesture { onToggleExpand() }
    }

    private var moreButton: some View {
        Button { onMoreTap() } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isMenuOpen ? .white : Theme.Color.muted)
                .frame(width: 28, height: 28)
                .background(isMenuOpen ? Theme.Color.accent : .clear, in: Circle())
        }
        .buttonStyle(.plain)
        // 发布 ⋯ 底部锚点，供父视图顶层菜单定位。
        .anchorPreference(key: ExerciseMenuAnchorKey.self, value: .bottomTrailing) {
            isMenuOpen ? $0 : nil
        }
    }

    private var addSetButton: some View {
        Button { addSet() } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                Text("加一组").font(Theme.Font.body(size: 12.5, weight: .semibold))
            }
            .foregroundStyle(Theme.Color.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .stroke(Theme.Color.border2, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .padding(.horizontal, 12).padding(.bottom, 12)
        }.buttonStyle(.plain)
    }

    private func addSet() {
        let next = (exercise.sets.map(\.setIndex).max() ?? -1) + 1
        let lastWeight = sortedSets.last?.weightKg
        exercise.sets.append(WorkoutSet(setIndex: next, weightKg: lastWeight))
        onChange()
    }
}

private struct SetRow: View {
    @Bindable var set: WorkoutSet
    /// 弱待办标记：该组为「第一个未完成组」（仅次序号/勾选弱提示，非编辑高亮）。
    let isTodo: Bool
    /// 只读态：禁用输入与完成勾选，不可聚焦。
    var readOnly: Bool = false
    /// 本组当前被聚焦的字段（nil = 未聚焦本组）；非 nil ⟺ 编辑高亮落在本组。
    let focusedField: SetField?
    /// 聚焦字段的编辑缓冲串（含 "0." / "72." 中间态）。
    let editingText: String
    let onChange: () -> Void
    let onComplete: () -> Void
    /// 请求聚焦本组某字段。
    let onFocus: (SetField) -> Void

    /// 编辑高亮 = 本组有字段被聚焦。
    private var isEditing: Bool { focusedField != nil }
    /// 弱强调（次序号/勾选环）：编辑中或待办。
    private var emphasized: Bool { isEditing || isTodo }

    var body: some View {
        // 原型 grid：[22 序号][1fr 重量][14 ×][1fr 次数][28 勾]。聚焦字段朱砂红高亮、待办仅弱提示。
        HStack(spacing: 8) {
            Text("\(set.setIndex + 1)")
                .font(Theme.Font.mono(size: 13, weight: .bold))
                .frame(width: 22)
                .foregroundStyle(snColor)
            valueCell(text: weightDisplay, placeholder: "kg", focused: focusedField == .weight,
                      label: "重量", value: set.weightKg.map { "\(formatKg($0)) 公斤" })
                .onTapGesture { if !readOnly { onFocus(.weight) } }
            Text("×").font(Theme.Font.mono(size: 11)).foregroundStyle(Theme.Color.muted).frame(width: 14)
            valueCell(text: repsDisplay, placeholder: "次", focused: focusedField == .reps,
                      label: "次数", value: set.reps.map { "\($0) 次" })
                .onTapGesture { if !readOnly { onFocus(.reps) } }
            checkButton
        }
        .opacity(set.completed ? 0.52 : 1)
        .padding(.horizontal, 15)
        .padding(.vertical, 5)
    }

    // 聚焦字段显示缓冲；否则显示模型格式化值。
    private var weightDisplay: String {
        focusedField == .weight ? editingText : (set.weightKg.map { formatKg($0) } ?? "")
    }
    private var repsDisplay: String {
        focusedField == .reps ? editingText : (set.reps.map(String.init) ?? "")
    }

    private func valueCell(text: String, placeholder: String, focused: Bool,
                           label: String, value: String?) -> some View {
        Text(text.isEmpty ? placeholder : text)
            .font(Theme.Font.number(size: 15, weight: .bold))
            .foregroundStyle(text.isEmpty ? Theme.Color.muted : Theme.Color.fg)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(focused ? Theme.Color.accentSoft : (isEditing ? Theme.Color.surface : Theme.Color.bg),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .stroke(focused ? Theme.Color.accent : Theme.Color.border,
                            lineWidth: focused ? 1.5 : 1)
            )
            .contentShape(Rectangle())
            .accessibilityElement()
            .accessibilityLabel("第 \(set.setIndex + 1) 组 \(label)")
            .accessibilityValue(value ?? "未填写")
            .accessibilityAddTraits(.isButton)
    }

    private var checkButton: some View {
        Button {
            set.completed.toggle()
            onChange()
            if set.completed { onComplete() }
        } label: {
            ZStack {
                if set.completed {
                    Circle().fill(Theme.Color.accent)
                        .shadow(color: Theme.Color.accent.opacity(0.28), radius: 5, y: 2)
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                } else if emphasized {
                    Circle().fill(Theme.Color.accent.opacity(0.18))
                    Circle().stroke(Theme.Color.accent.opacity(0.4), lineWidth: 2)
                } else {
                    Circle().stroke(Theme.Color.border, lineWidth: 1.5)
                }
            }
            .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain).disabled(readOnly)
        .frame(width: 28)
        .accessibilityLabel(set.completed ? "第 \(set.setIndex + 1) 组已完成" : "标记第 \(set.setIndex + 1) 组完成")
    }

    private var snColor: SwiftUI.Color { emphasized ? Theme.Color.accent : Theme.Color.muted }
}
