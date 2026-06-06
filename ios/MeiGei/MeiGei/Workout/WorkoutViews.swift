import SwiftUI
import SwiftData

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
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    if let active = activeSession { continueBanner(active) }
                    heroSection
                    statsGrid
                    recentSection
                    Color.clear.frame(height: 80) // 给底部 CTA 留位
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }
            startCTA
        }
        .navigationTitle("训练")
        .navigationBarTitleDisplayMode(.inline)
        // 工具栏左右上角入口均已移除：右上角原「搜索占位 + 加号菜单」、左上角「日历 / 训练历史」
        // （历史模块已删，留待后续单独立项）。开始训练唯一收敛到底部悬浮 CTA。
        .navigationDestination(for: Workout.self) { WorkoutLoggingView(workout: $0) }
        .navigationDestination(item: $openedSession) { WorkoutLoggingView(workout: $0) }
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
        .confirmationDialog("删除这次训练？", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }), presenting: pendingDelete) { w in
            Button("删除", role: .destructive) {
                Theme.Haptics.notification(.warning)
                w.markDeleted()
                try? modelContext.save()
            }
            Button("取消", role: .cancel) {}
        } message: { _ in Text("删除后将从列表移除、不再计入统计，且同步到云端。") }
    }

    // MARK: 继续训练横幅（仅在存在进行中会话时显示）

    private func continueBanner(_ w: Workout) -> some View {
        let totalSets = w.exercises.reduce(0) { $0 + $1.sets.count }
        let doneSets = w.exercises.flatMap(\.sets).filter(\.completed).count
        return Button {
            Theme.Haptics.impact(.light)
            openedSession = w
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle().fill(Theme.Color.danger.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: "figure.run")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.Color.danger)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("LIVE · 进行中").eyebrowStyle().foregroundStyle(Theme.Color.danger)
                    Text(w.title ?? "训练")
                        .font(Theme.Font.body(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Color.fg)
                    Text("\(w.exercises.count) 动作 · \(doneSets)/\(totalSets) 组完成")
                        .font(Theme.Font.body(size: 12))
                        .foregroundStyle(Theme.Color.fg2)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("继续").font(Theme.Font.body(size: 14, weight: .semibold))
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Theme.Color.danger)
            }
            .cardStyle()
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(Theme.Color.danger.opacity(0.55), lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("继续训练 \(w.title ?? "训练")，\(w.exercises.count) 个动作，\(doneSets)/\(totalSets) 组完成")
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
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("THIS WEEK · 本周训练量").eyebrowStyle()
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(formatTons(stats.volumeKg)).numStyle(size: 56)
                        .foregroundStyle(Theme.Color.accentCyan)
                        .shadow(color: Theme.Color.accentCyan.opacity(0.55), radius: 14)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("t").numStyle(size: 22).foregroundStyle(Theme.Color.fg2)
                }
                Text("本周第 \(weeklyDoneCount) 次训练")
                    .font(Theme.Font.body(size: 13))
                    .foregroundStyle(Theme.Color.fg2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
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
                            onDelete: { pendingDelete = w }
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
                        .foregroundStyle(Theme.Color.accentMagenta)
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
            .background(Theme.Color.accentCyan, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .neonGlow(.cyan, intensity: .medium, cornerRadius: Theme.Radius.md)
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
private struct SwipeToDeleteCard<Content: View>: View {
    var onTap: () -> Void
    var onDelete: () -> Void
    @ViewBuilder var content: Content
    @State private var offset: CGFloat = 0
    /// 越阈触感去抖：仅在首次越过删除显露阈值时触发一次 selection。
    @State private var didReveal = false
    private let revealed: CGFloat = -76
    /// 显露 / 收回统一回弹，保证手感对称。
    private let snap: Animation = .spring(response: 0.3, dampingFraction: 0.8)

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive) {
                withAnimation(snap) { offset = 0 }
                onDelete()
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
            .accessibilityAction(named: "删除") { onDelete() }
        }
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
    @State private var isRestExpanded = false
    /// 已完成会话显式编辑态；进行中会话恒为可编辑。
    @State private var isEditing = false
    /// 结束二次确认弹窗。
    @State private var confirmingFinish = false

    /// 是否允许编辑内容（勾选完成 / 改重量次数 / 加删动作）：进行中或已完成且进入编辑态。
    private var canEdit: Bool { workout.isActive || isEditing }

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
    private var sheetAnim: Animation { reduceMotion ? .easeInOut(duration: 0.2) : .spring() }

    /// 下一组提示：找第一个未完成 set 所属动作 + setIndex。
    private var nextHint: String? {
        for ex in workout.exercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            if let next = ex.sets.sorted(by: { $0.setIndex < $1.setIndex })
                .first(where: { !$0.completed }) {
                return "下一组：\(ex.exerciseName) · 第 \(next.setIndex + 1) 组"
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
                    if isEditing { editTimeCard }
                    exerciseList
                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.sm)
            }
            // 浮动 FAB（仅在 rest 进行中显示且未展开）
            if restTimer.isRunning && !isRestExpanded {
                restFAB
                    .padding(.trailing, Theme.Spacing.lg)
                    .padding(.bottom, 90)
                    // 「减弱动态效果」开启时只淡入淡出，不做缩放入场。
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            }
            if isRestExpanded {
                RestTimerSheet(controller: restTimer,
                               nextHint: nextHint) {
                    withAnimation(sheetAnim) { isRestExpanded = false }
                }
            }
        }
        .navigationTitle(workout.title ?? "训练")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 已完成会话：显式「编辑 / 完成」切换（进行中会话恒可编辑，不显示此入口）。
            if workout.isFinished {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "完成" : "编辑") {
                        if isEditing { exitEditing() } else { isEditing = true }
                    }
                    .foregroundStyle(Theme.Color.accentCyan)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("休息时长", selection: Binding(
                        get: { restTimer.defaultDuration },
                        set: { restTimer.defaultDuration = $0 })) {
                        ForEach([Double](arrayLiteral: 30, 45, 60, 90, 120, 150, 180), id: \.self) { secs in
                            Text("\(Int(secs)) 秒").tag(secs)
                        }
                    }
                    if canEdit {
                        Button { pickingExercise = true } label: { Label("添加动作", systemImage: "plus") }
                    }
                } label: { Image(systemName: "ellipsis").foregroundStyle(Theme.Color.fg) }
            }
        }
        .confirmationDialog("结束这次训练？", isPresented: $confirmingFinish, titleVisibility: .visible) {
            Button("结束训练") { finish() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("\(workout.exercises.count) 动作 · \(completedSetCount) 组完成。结束后将归档，可在「编辑」中继续修改。")
        }
        .sheet(isPresented: $pickingExercise) {
            ExercisePickerView { pick in addExercise(pick) }
        }
        .sheet(isPresented: Binding(get: { celebration != nil }, set: { if !$0 { celebration = nil } })) {
            if let celebration { PRCelebrationSheet(records: celebration) }
        }
        .onChange(of: restTimer.isRunning) { _, running in
            // 倒计时归零时自动收回弹窗。
            if !running { withAnimation(sheetAnim) { isRestExpanded = false } }
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
        VStack(spacing: 4) {
            Text(value).numStyle(size: 20).foregroundStyle(Theme.Color.accentCyan)
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

    private var exerciseList: some View {
        let sorted = workout.exercises.sorted { $0.orderIndex < $1.orderIndex }
        return VStack(spacing: Theme.Spacing.md) {
            ForEach(sorted) { ex in
                ExerciseBlock(exercise: ex,
                              readOnly: !canEdit,
                              onChange: touch,
                              onCompleteSet: { restTimer.start(label: ex.exerciseName) },
                              onDeleteExercise: { delete(ex) })
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

    // MARK: 编辑态时长修正（修正墙钟被遗弃拉长的脏数据）

    @ViewBuilder private var editTimeCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("EDIT · 时长修正").eyebrowStyle()
            DatePicker("开始", selection: Binding(
                get: { workout.startedAt },
                set: { workout.startedAt = $0; touch() }))
                .foregroundStyle(Theme.Color.fg)
            DatePicker("结束", selection: Binding(
                get: { workout.endedAt ?? workout.startedAt },
                set: { workout.endedAt = max($0, workout.startedAt); touch() }))
                .foregroundStyle(Theme.Color.fg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: FAB

    private var restFAB: some View {
        Button {
            withAnimation(sheetAnim) { isRestExpanded = true }
        } label: {
            TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                let total = restTimer.totalDuration
                let remaining = restTimer.remaining
                let progress = total > 0 ? min(max(remaining / total, 0), 1) : 0
                ZStack {
                    Circle().fill(Theme.Color.surface)
                    Circle().stroke(Theme.Color.border, lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Theme.Color.accentCyan, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(formatMMSS(remaining))
                        .font(Theme.Font.number(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Color.fg)
                }
                .frame(width: 64, height: 64)
                .shadow(color: Theme.Color.accentCyan.opacity(0.55), radius: 8)
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

    /// 退出已完成会话的编辑态：保存后重算 PR 并更新 Team 打卡摘要。
    private func exitEditing() {
        isEditing = false
        touch()
        recomputeDerived()
    }

    /// 重算派生数据：PR 检测（命中弹庆祝）+ Team 打卡（按 localId 幂等：首次创建、编辑后更新摘要）。
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
                        .foregroundStyle(Theme.Color.accentCyan)
                    Text("时长 · \(formatHMS(endedAt!.timeIntervalSince(startedAt)))")
                        .font(Theme.Font.number(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Color.fg)
                } else {
                    // 进行中：墙钟实时计时（含组间休息，无暂停）。
                    // 「减弱动态效果」开启时不做 repeatForever 脉冲，呈静态红点。
                    Circle().fill(Theme.Color.danger)
                        .frame(width: 10, height: 10)
                        .scaleEffect(reduceMotion ? 1.0 : (pulse ? 1.0 : 0.7))
                        .opacity(reduceMotion ? 1.0 : (pulse ? 1.0 : 0.6))
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                        .onAppear { if !reduceMotion { pulse = true } }
                    TimelineView(.periodic(from: .now, by: 1.0)) { ctx in
                        Text("REC · \(formatHMS(ctx.date.timeIntervalSince(startedAt)))")
                            .font(Theme.Font.number(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.Color.fg)
                    }
                }
            }
            Spacer()
            if isEnded {
                Text("已完成").font(Theme.Font.body(size: 12)).foregroundStyle(Theme.Color.muted)
            } else {
                // 进行中仅有「结束」（已移除会话级暂停）。
                Button(action: onFinish) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Theme.Color.danger, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("结束训练")
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.Color.border, lineWidth: 1))
    }
}

private func formatHMS(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded()))
    return String(format: "%d:%02d", total / 60, total % 60)
}

// MARK: - 动作分组卡

private struct ExerciseBlock: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var exercise: WorkoutExercise
    /// 只读态（已完成且未进入编辑）：隐藏菜单、禁用组内操作。
    var readOnly: Bool = false
    let onChange: () -> Void
    let onCompleteSet: () -> Void
    let onDeleteExercise: () -> Void

    private var sortedSets: [WorkoutSet] {
        exercise.sets.sorted { $0.setIndex < $1.setIndex }
    }
    /// 当前活跃 set：第一个未完成的；若全部完成则没有 active。
    private var activeSetIndex: Int? {
        sortedSets.first(where: { !$0.completed })?.setIndex
    }
    /// 整个动作是否完成（所有 set 都 completed）。
    private var isAllDone: Bool {
        !sortedSets.isEmpty && sortedSets.allSatisfy(\.completed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(exercise.exerciseName)
                    .font(Theme.Font.body(size: 15, weight: .semibold))
                    .foregroundStyle(isAllDone ? Theme.Color.muted : Theme.Color.fg)
                    .strikethrough(isAllDone)
                if isAllDone {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Color.accentCyan)
                }
                Spacer()
                if !readOnly {
                    Menu {
                        Button { addSet() } label: { Label("加一组", systemImage: "plus") }
                        Button(role: .destructive) { onDeleteExercise() } label: { Label("删除", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(Theme.Color.muted)
                            .frame(width: 28, height: 28)
                    }
                }
            }
            VStack(spacing: 6) {
                ForEach(sortedSets) { set in
                    SetRow(set: set,
                           isActive: activeSetIndex == set.setIndex,
                           readOnly: readOnly,
                           onChange: onChange,
                           onComplete: onCompleteSet)
                }
            }
        }
        .cardStyle()
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
        HStack(spacing: 12) {
            Text("\(set.setIndex + 1)")
                .font(Theme.Font.number(size: 13, weight: .semibold))
                .frame(width: 22)
                .foregroundStyle(textColor)
            numberField("kg", value: $set.weightKg).foregroundStyle(textColor).disabled(readOnly)
            Text("×").foregroundStyle(Theme.Color.muted)
            intField("次", value: $set.reps).foregroundStyle(textColor).disabled(readOnly)
            Spacer()
            Button {
                set.completed.toggle()
                onChange()
                if set.completed { onComplete() }
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(set.completed ? Theme.Color.accentCyan : Theme.Color.muted)
            }.buttonStyle(.plain).disabled(readOnly)
            .accessibilityLabel(set.completed ? "第 \(set.setIndex + 1) 组已完成" : "标记第 \(set.setIndex + 1) 组完成")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(rowBg, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(isActive ? Theme.Color.accentCyan.opacity(0.4) : .clear, lineWidth: 1)
        )
    }

    private var rowBg: SwiftUI.Color {
        if isActive { return Theme.Color.accentCyan.opacity(0.10) }
        return Theme.Color.surface2
    }
    private var textColor: SwiftUI.Color {
        if set.completed { return Theme.Color.muted }
        if isActive { return Theme.Color.accentCyan }
        return Theme.Color.fg
    }

    private func numberField(_ placeholder: String, value: Binding<Double?>) -> some View {
        TextField(placeholder, text: Binding(
            get: { value.wrappedValue.map { formatKg($0) } ?? "" },
            set: { value.wrappedValue = Double($0.replacingOccurrences(of: ",", with: ".")); onChange() }
        ))
        .keyboardType(.decimalPad)
        .frame(width: 64).multilineTextAlignment(.center)
        .font(Theme.Font.number(size: 14, weight: .semibold))
        .padding(.vertical, 4)
        .background(Theme.Color.bg, in: RoundedRectangle(cornerRadius: 6))
    }

    private func intField(_ placeholder: String, value: Binding<Int?>) -> some View {
        TextField(placeholder, text: Binding(
            get: { value.wrappedValue.map(String.init) ?? "" },
            set: { value.wrappedValue = Int($0); onChange() }
        ))
        .keyboardType(.numberPad)
        .frame(width: 50).multilineTextAlignment(.center)
        .font(Theme.Font.number(size: 14, weight: .semibold))
        .padding(.vertical, 4)
        .background(Theme.Color.bg, in: RoundedRectangle(cornerRadius: 6))
    }
}
