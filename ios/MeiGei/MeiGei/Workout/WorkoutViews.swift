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
    @State private var conflict: Workout?
    @State private var pendingBuild: (() -> Workout)?
    /// 待删除的已完成训练（左滑删除二次确认）。
    @State private var pendingDelete: Workout?
    /// 待删训练行的全局坐标，供删除确认卡片定位于其正下方。
    @State private var deleteRect: CGRect = .zero

    /// 当前唯一进行中会话（首页横幅来源）。
    private var activeSession: Workout? { workouts.first(where: { $0.isActive }) }
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
                }
            }
            startCTA
        }
        // LIVE 悬浮胶囊：有活跃会话时浮于内容之上，可拖拽、吸附边缘、点击直达进行中页。
        .overlay {
            if let active = activeSession {
                LiveSessionCapsule(title: active.title ?? "训练") {
                    openedSession = active
                }
            }
        }
        // 首页 Header 用自绘大标题（训练 + YU 头像，对齐设计图 .nav），隐藏系统导航栏。
        // 工具栏左右上角入口均已移除：右上角原「搜索占位 + 加号菜单」、左上角「日历 / 训练历史」
        // （历史模块已删，留待后续单独立项）。开始训练唯一收敛到底部悬浮 CTA。
        .toolbar(.hidden, for: .navigationBar)
        // 已完成训练 → 只读训练日志详情；进行中会话 → Live 记录界面。
        .navigationDestination(for: Workout.self) { workoutDestination($0) }
        .navigationDestination(item: $openedSession) { workoutDestination($0) }
        .confirmationDialog("已有进行中的训练", isPresented: Binding(
            get: { conflict != nil },
            set: { if !$0 { conflict = nil; pendingBuild = nil } }), presenting: conflict) { existing in
            Button("继续训练") { openedSession = existing; pendingBuild = nil }
            Button("丢弃并开始新训练", role: .destructive) {
                WorkoutSession.discard(existing, in: modelContext)
                if let build = pendingBuild { commit(build) }
                pendingBuild = nil
            }
            Button("取消", role: .cancel) { pendingBuild = nil }
        } message: { _ in Text("同一时间只能有一个进行中的训练。继续既有训练，或丢弃后开始新的。") }
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
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(recent) { w in
                        SwipeToDeleteCard(
                            onTap: { openedSession = w },
                            onDelete: { rect in
                                deleteRect = rect
                                pendingDelete = w
                            }
                        ) { recentRow(w) }
                    }
                }
            }
        }
    }

    private func recentRow(_ w: Workout) -> some View {
        let totalSets = w.exercises.reduce(0) { $0 + $1.sets.count }
        let durationMin: Int? = w.endedAt.map { Int($0.timeIntervalSince(w.startedAt) / 60) }
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
        } else {
            commit(build)
        }
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

/// 训练首页「最近训练」是 ScrollView 内的卡片栈而非 List，无法用 `.swipeActions`，
/// 故以轻量水平拖动手势实现左滑显露删除按钮；点击空白处收回，点击卡片走 onTap。
/// 计划详情页的动作行复用同一交互（见 PlanViews）。
struct SwipeToDeleteCard<Content: View>: View {
    var onTap: () -> Void
    /// 回传该行的全局坐标，供父视图把删除确认卡片定位于其正下方。
    var onDelete: (CGRect) -> Void
    @ViewBuilder var content: Content
    @State private var offset: CGFloat = 0
    /// 越阈触感去抖：仅在首次越过删除显露阈值时触发一次 selection。
    @State private var didReveal = false
    /// 本行在屏幕中的全局 frame（随布局更新），删除时随回调一并回传。
    @State private var globalFrame: CGRect = .zero
    private let revealed: CGFloat = -76
    /// 显露 / 收回统一回弹，保证手感对称。
    private let snap: Animation = .spring(response: 0.3, dampingFraction: 0.8)

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive) {
                withAnimation(snap) { offset = 0 }
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

            // 点击走 Button 以获得按压微反馈；横向拖动经 highPriorityGesture 接管，互不冲突。
            Button {
                if offset < 0 { withAnimation(snap) { offset = 0 } }
                else { onTap() }
            } label: {
                content
            }
            .buttonStyle(PressableButtonStyle())
            .offset(x: offset)
            .highPriorityGesture(
                DragGesture(minimumDistance: 16)
                    .onChanged { v in
                        guard abs(v.translation.width) > abs(v.translation.height) else { return }
                        if v.translation.width < 0 { offset = max(v.translation.width, revealed) }
                        else if offset < 0 { offset = min(0, revealed + v.translation.width) }
                        // 越过显露阈值首次触发选择触感，回到阈值内复位去抖标记。
                        if offset <= -40, !didReveal { Theme.Haptics.selection(); didReveal = true }
                        if offset > -40 { didReveal = false }
                    }
                    .onEnded { v in
                        withAnimation(snap) {
                            offset = v.translation.width < -40 ? revealed : 0
                        }
                    }
            )
            // 左滑手势对 VoiceOver 不可达，提供等价删除自定义动作（走同一二次确认）。
            .accessibilityAction(named: "删除") { onDelete(globalFrame) }
        }
        // 持续记录本行的全局 frame（屏幕坐标系），供删除确认卡片定位于其正下方。
        .background(GeometryReader { g in
            Color.clear
                .onAppear { globalFrame = g.frame(in: .global) }
                .onChange(of: g.frame(in: .global)) { _, new in globalFrame = new }
        })
    }
}

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

/// 训练进行中页（旧 WorkoutLoggingView 升级为新视觉，符号名保留以避免破坏 HistoryViews 等引用）。
struct WorkoutLoggingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TeamService.self) private var teamService
    @Environment(RestTimerController.self) private var restTimer
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var workout: Workout
    @State private var pickingExercise = false
    @State private var celebration: [PersonalRecord]?
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
            parts.append("\(Int(end.timeIntervalSince(workout.startedAt) / 60)) 分钟")
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
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    LiveHeaderView(startedAt: workout.startedAt,
                                   endedAt: workout.endedAt,
                                   onFinish: { confirmingFinish = true })
                    triadStats
                    exerciseList
                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.sm)
            }
            // 浮动 FAB（仅在 rest 进行中显示且未展开）。本屏无 Tab Bar，贴右下角常驻。
            // 全屏休息弹窗已上提到 MainTabView 的根层 overlay（层级高于 Tab/Nav，无需隐藏两栏）。
            if restTimer.isRunning && !restTimer.isExpanded {
                restFAB
                    .padding(.trailing, Theme.Spacing.lg)
                    .padding(.bottom, 28)
                    // 「减弱动态效果」开启时只淡入淡出，不做缩放入场。
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            }
        }
        .navigationTitle(workout.isActive ? "记录中" : (workout.title ?? "训练"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
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
        .toolbar {
            // 圆形返回键（对齐原型 .back：白底 + 描边 + 轻阴影）。
            // iOS 26 工具栏会给按钮自动套一层 Liquid Glass 圆形背景，与自绘的纸感圆叠成「双环」；
            // 用 sharedBackgroundVisibility(.hidden) 关掉系统背景，仅保留我们的圆。
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .topBarLeading) {
                    CircleIconButton(systemName: "chevron.left", action: { dismiss() }, size: 32)
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .topBarLeading) {
                    CircleIconButton(systemName: "chevron.left", action: { dismiss() }, size: 32)
                }
            }
            // 组间休息已移入每个动作卡右上 ⋯ 菜单（动作级设置）；已完成训练只读，导航栏不再挂编辑入口。
        }
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
        .sheet(isPresented: Binding(get: { celebration != nil }, set: { if !$0 { celebration = nil } })) {
            if let celebration { PRCelebrationSheet(records: celebration, summary: prSummary) }
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

    private var restFAB: some View {
        Button {
            withAnimation(sheetAnim) { restTimer.isExpanded = true }
        } label: {
            TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                let total = restTimer.totalDuration
                let remaining = restTimer.remaining
                let progress = total > 0 ? min(max(remaining / total, 0), 1) : 0
                ZStack {
                    Circle().fill(Theme.Color.surface)
                    // 环形进度（消耗式 满→空），内嵌于 2px 实边之内（对齐原型 svg r=22）：
                    // 轨道 accent-3（18% 朱砂红）+ 进度朱砂红，round 端点。
                    ZStack {
                        Circle().stroke(Theme.Color.accentSofter, lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Theme.Color.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.3), value: progress)
                    }
                    .padding(4)
                    Text("\(Int(remaining.rounded()))s")
                        .font(Theme.Font.number(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.Color.accent)
                }
                .frame(width: 52, height: 52)
                .overlay(Circle().stroke(Theme.Color.accent, lineWidth: 2))
                // box-shadow: 朱砂红辉光 22% + 中性 sh-md。
                .shadow(color: Theme.Color.accent.opacity(0.22), radius: 9, x: 0, y: 4)
                .shadow(color: Theme.Color.fg.opacity(Theme.ShadowLevel.md.opacity), radius: Theme.ShadowLevel.md.radius, x: 0, y: Theme.ShadowLevel.md.y)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("休息计时，点按展开")
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

    /// 结束训练（二次确认后调用）：置 endedAt + HealthKit 写入，再统一重算派生数据。
    private func finish() {
        Theme.Haptics.notification(.success)
        let endedAt = Date.now
        workout.endedAt = endedAt
        touch()
        let startedAt = workout.startedAt
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
            if !prs.isEmpty { celebration = prs }
        }
        let snapshot = workout
        Task { try? await teamService.checkIn(workout: snapshot) }
    }

    private func touch() {
        workout.markDirty()
        try? modelContext.save()
    }
}

// MARK: - LiveHeader: REC · MM:SS + 暂停/结束

private struct LiveHeaderView: View {
    let startedAt: Date
    /// nil = 进行中（墙钟实时计时）；非 nil = 已完成（计时冻结为 endedAt − startedAt）。
    let endedAt: Date?
    let onFinish: () -> Void
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isEnded: Bool { endedAt != nil }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            HStack(spacing: 8) {
                if isEnded {
                    // 已完成：静态时长，无录制点、不再增长。
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Color.accent)
                    Text("时长 · \(formatHMS(endedAt!.timeIntervalSince(startedAt)))")
                        .font(Theme.Font.number(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Color.fg)
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
                        Text(formatHMS(ctx.date.timeIntervalSince(startedAt)))
                            .font(Theme.Font.number(size: 15, weight: .bold))
                            .foregroundStyle(Theme.Color.fg)
                    }
                }
            }
            Spacer()
            if isEnded {
                Text("已完成").font(Theme.Font.l4).foregroundStyle(Theme.Color.muted)
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

private struct ExerciseBlock: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var exercise: WorkoutExercise
    /// 只读态（已完成且未进入编辑）：隐藏菜单、禁用组内操作。
    var readOnly: Bool = false
    /// 手风琴：是否展开 set 列表（false 时折叠为单行摘要）。
    var isExpanded: Bool = true
    /// ⋯ 组间休息菜单是否打开（菜单本体由父视图顶层浮层渲染）。
    var isMenuOpen: Bool = false
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
                               isActive: activeSetIndex == set.setIndex,
                               readOnly: readOnly,
                               onChange: onChange,
                               onComplete: onCompleteSet)
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
    let isActive: Bool
    /// 只读态：禁用输入框与完成勾选。
    var readOnly: Bool = false
    let onChange: () -> Void
    let onComplete: () -> Void

    var body: some View {
        // 原型 grid：[22 序号][1fr 重量][14 ×][1fr 次数][28 勾]，激活行朱砂红 8% 底+描边。
        HStack(spacing: 8) {
            Text("\(set.setIndex + 1)")
                .font(Theme.Font.mono(size: 13, weight: .bold))
                .frame(width: 22)
                .foregroundStyle(snColor)
            numberField("kg", value: $set.weightKg).disabled(readOnly)
            Text("×").font(Theme.Font.mono(size: 11)).foregroundStyle(Theme.Color.muted).frame(width: 14)
            intField("次", value: $set.reps).disabled(readOnly)
            checkButton
        }
        .opacity(set.completed ? 0.52 : 1)
        .padding(.horizontal, isActive ? 9 : 15)
        .padding(.vertical, isActive ? 6 : 5)
        .background(isActive ? Theme.Color.accentSoft : .clear,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        .padding(.horizontal, isActive ? 6 : 0)
        .padding(.vertical, isActive ? 2 : 0)
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
                } else if isActive {
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

    private var snColor: SwiftUI.Color { isActive ? Theme.Color.accent : Theme.Color.muted }

    private func numberField(_ placeholder: String, value: Binding<Double?>) -> some View {
        TextField("", text: Binding(
            get: { value.wrappedValue.map { formatKg($0) } ?? "" },
            set: { value.wrappedValue = Double($0.replacingOccurrences(of: ",", with: ".")); onChange() }
        ), prompt: Text(placeholder).foregroundColor(Theme.Color.muted))
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.center)
        .font(Theme.Font.number(size: 15, weight: .bold))
        .foregroundStyle(Theme.Color.fg)
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .background(isActive ? Theme.Color.surface : Theme.Color.bg,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .stroke(isActive ? Theme.Color.accent.opacity(0.35) : Theme.Color.border, lineWidth: 1)
        )
    }

    private func intField(_ placeholder: String, value: Binding<Int?>) -> some View {
        TextField("", text: Binding(
            get: { value.wrappedValue.map(String.init) ?? "" },
            set: { value.wrappedValue = Int($0); onChange() }
        ), prompt: Text(placeholder).foregroundColor(Theme.Color.muted))
        .keyboardType(.numberPad)
        .multilineTextAlignment(.center)
        .font(Theme.Font.number(size: 15, weight: .bold))
        .foregroundStyle(Theme.Color.fg)
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .background(isActive ? Theme.Color.surface : Theme.Color.bg,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .stroke(isActive ? Theme.Color.accent.opacity(0.35) : Theme.Color.border, lineWidth: 1)
        )
    }
}
