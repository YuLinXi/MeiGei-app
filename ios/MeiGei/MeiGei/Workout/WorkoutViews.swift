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
    @State private var active: Workout?
    @State private var choosingPlan = false

    private var stats: WeeklyStats {
        WorkoutWeeklyStats.compute(workouts: workouts)
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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink { TrainingHistoryView() } label: {
                    Image(systemName: "calendar").foregroundStyle(Theme.Color.fg)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 14) {
                    // 搜索 sheet 留到后续 change，先占位。
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.Color.fg2)
                    Menu {
                        Button("空白训练") { startBlank() }
                        if !plans.isEmpty {
                            Divider()
                            ForEach(plans) { p in Button("从「\(p.name)」开始") { start(from: p) } }
                        }
                    } label: { Image(systemName: "plus").foregroundStyle(Theme.Color.fg) }
                }
            }
        }
        .navigationDestination(for: Workout.self) { WorkoutLoggingView(workout: $0) }
        .navigationDestination(item: $active) { WorkoutLoggingView(workout: $0) }
    }

    // MARK: Hero

    @ViewBuilder private var heroSection: some View {
        if weeklyDoneCount == 0 {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("THIS WEEK · 本周").eyebrowStyle()
                Text("准备好了吗？")
                    .font(Theme.Font.display(size: 32, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                Text("本周还没开始 · 现在开始第 1 次训练")
                    .font(Theme.Font.body(size: 13))
                    .foregroundStyle(Theme.Color.fg2)
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
                    Text("t").numStyle(size: 22).foregroundStyle(Theme.Color.fg2)
                }
                Text("本周第 \(weeklyDoneCount) 次训练")
                    .font(Theme.Font.body(size: 13))
                    .foregroundStyle(Theme.Color.fg2)
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
            Text(label).eyebrowStyle()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(Theme.Color.border).frame(width: 1)
    }

    // MARK: 最近训练

    private var recentSection: some View {
        let recent = Array(workouts.prefix(8))
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
                        NavigationLink(value: w) {
                            recentRow(w)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func recentRow(_ w: Workout) -> some View {
        let totalSets = w.exercises.reduce(0) { $0 + $1.sets.count }
        let durationMin: Int? = w.endedAt.map { Int($0.timeIntervalSince(w.startedAt) / 60) }
        let pr = prByWorkout[w.localId]
        return HStack(spacing: Theme.Spacing.md) {
            dateBlock(w.startedAt)
            VStack(alignment: .leading, spacing: 4) {
                Text(w.title ?? "训练")
                    .font(Theme.Font.body(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                Text("\(w.exercises.count) 动作 · \(totalSets) 组" + (durationMin.map { " · \($0)′" } ?? ""))
                    .font(Theme.Font.body(size: 12))
                    .foregroundStyle(Theme.Color.fg2)
                if let pr {
                    Text("▲ \(pr.name) PR \(formatKg(pr.weight))kg")
                        .font(Theme.Font.body(size: 11, weight: .medium))
                        .foregroundStyle(Theme.Color.accentMagenta)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Color.muted)
        }
        .cardStyle()
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

    private var startCTA: some View {
        Button { startBlank() } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                Text(weeklyDoneCount == 0 ? "开始第 1 次训练" : "开始今日训练")
            }
            .font(Theme.Font.body(size: 16, weight: .semibold))
            .foregroundStyle(Theme.Color.bg)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Theme.Color.accentCyan, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .neonGlow(.cyan, intensity: .medium, cornerRadius: Theme.Radius.md)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, 16) // tab bar 之上留 16pt
    }

    // MARK: actions

    private func startBlank() {
        let w = Workout(title: "训练")
        modelContext.insert(w)
        try? modelContext.save()
        active = w
    }

    private func start(from plan: WorkoutPlan) {
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
        modelContext.insert(w)
        try? modelContext.save()
        active = w
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
    @Bindable var workout: Workout
    @State private var pickingExercise = false
    @State private var sharingSummary: CheckinSummary?
    @State private var celebration: [PersonalRecord]?
    @State private var isRestExpanded = false

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
                                   isEnded: workout.endedAt != nil,
                                   onFinish: finish)
                    triadStats
                    exerciseList
                    if workout.endedAt != nil {
                        Button { sharingSummary = CheckinSummary(workout: workout) } label: {
                            Label("生成分享海报", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity).frame(height: 44)
                                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.Color.border, lineWidth: 1))
                                .foregroundStyle(Theme.Color.fg)
                        }
                        .buttonStyle(.plain)
                    }
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
                    .transition(.scale.combined(with: .opacity))
            }
            if isRestExpanded {
                RestTimerSheet(controller: restTimer,
                               nextHint: nextHint) {
                    withAnimation(.spring()) { isRestExpanded = false }
                }
            }
        }
        .navigationTitle(workout.title ?? "训练")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("休息时长", selection: Binding(
                        get: { restTimer.defaultDuration },
                        set: { restTimer.defaultDuration = $0 })) {
                        ForEach([Double](arrayLiteral: 30, 45, 60, 90, 120, 150, 180), id: \.self) { secs in
                            Text("\(Int(secs)) 秒").tag(secs)
                        }
                    }
                    Button { pickingExercise = true } label: { Label("添加动作", systemImage: "plus") }
                } label: { Image(systemName: "ellipsis").foregroundStyle(Theme.Color.fg) }
            }
        }
        .sheet(isPresented: $pickingExercise) {
            ExercisePickerView { pick in addExercise(pick) }
        }
        .sheet(item: $sharingSummary) { SharePosterSheet(summary: $0) }
        .sheet(isPresented: Binding(get: { celebration != nil }, set: { if !$0 { celebration = nil } })) {
            if let celebration { PRCelebrationSheet(records: celebration) }
        }
        .onChange(of: restTimer.isRunning) { _, running in
            // 倒计时归零时自动收回弹窗。
            if !running { withAnimation(.spring()) { isRestExpanded = false } }
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
                              onChange: touch,
                              onCompleteSet: { restTimer.start(label: ex.exerciseName) },
                              onDeleteExercise: { delete(ex) })
            }
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

    // MARK: FAB

    private var restFAB: some View {
        Button {
            withAnimation(.spring()) { isRestExpanded = true }
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

    private func finish() {
        let endedAt = Date.now
        workout.endedAt = endedAt
        touch()
        let startedAt = workout.startedAt
        Task { await healthKit.saveStrengthWorkout(start: startedAt, end: endedAt) }
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
    let isEnded: Bool
    let onFinish: () -> Void
    @State private var paused = false
    @State private var pulse = false

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            HStack(spacing: 8) {
                Circle().fill(Theme.Color.danger)
                    .frame(width: 10, height: 10)
                    .scaleEffect(pulse ? 1.0 : 0.7)
                    .opacity(pulse ? 1.0 : 0.6)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                    .onAppear { pulse = true }
                TimelineView(.periodic(from: .now, by: 1.0)) { ctx in
                    Text("REC · \(formatHMS(ctx.date.timeIntervalSince(startedAt)))")
                        .font(Theme.Font.number(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Color.fg)
                }
            }
            Spacer()
            if !isEnded {
                Button {
                    paused.toggle()
                } label: {
                    Image(systemName: paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Color.fg)
                        .frame(width: 36, height: 36)
                        .background(Theme.Color.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(Theme.Color.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Button(action: onFinish) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Theme.Color.danger, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
                }
                .buttonStyle(.plain)
            } else {
                Text("已完成").font(Theme.Font.body(size: 12)).foregroundStyle(Theme.Color.muted)
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
                Menu {
                    Button { addSet() } label: { Label("加一组", systemImage: "plus") }
                    Button(role: .destructive) { onDeleteExercise() } label: { Label("删除", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Theme.Color.muted)
                        .frame(width: 28, height: 28)
                }
            }
            VStack(spacing: 6) {
                ForEach(sortedSets) { set in
                    SetRow(set: set,
                           isActive: activeSetIndex == set.setIndex,
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
    let onChange: () -> Void
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(set.setIndex + 1)")
                .font(Theme.Font.number(size: 13, weight: .semibold))
                .frame(width: 22)
                .foregroundStyle(textColor)
            numberField("kg", value: $set.weightKg).foregroundStyle(textColor)
            Text("×").foregroundStyle(Theme.Color.muted)
            intField("次", value: $set.reps).foregroundStyle(textColor)
            Spacer()
            Button {
                set.completed.toggle()
                onChange()
                if set.completed { onComplete() }
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(set.completed ? Theme.Color.accentCyan : Theme.Color.muted)
            }.buttonStyle(.plain)
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
