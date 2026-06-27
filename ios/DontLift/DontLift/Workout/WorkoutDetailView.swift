import SwiftUI
import SwiftData

// MARK: - 已完成训练详情（设计稿 Screen 2b · 训练日志）

/// 从首页「最近训练」点入的二级只读页。
///
/// 不复用「记录中」的输入表单（`WorkoutLoggingView` 只读态），而是一份**训练账本**：
/// 完成头卡（日期/时段/时长）→ 已完成口径三联数（时长 / 总组数 / 训练量）→ PR 高光条
/// → 逐动作逐组的「重量 × 次数」只读流水。朱砂红仅留给 PR / 顶组，无输入框、无勾选圈。
/// 已完成训练产品上不可二次编辑，故全程只读；删除经导航栏右上 ⋯。
struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkoutHistoryStore.self) private var historyStore
    @Bindable var workout: Workout

    @State private var confirmingDelete = false
    @State private var fallbackRecords: [PersonalRecord]?

    private static let weekdayFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "EEE"
        return fmt
    }()

    private static let timeFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "HH:mm"
        return fmt
    }()

    private var sortedExercises: [WorkoutExercise] {
        workout.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    /// 本次训练相对「此前」历史识别出的新纪录（与首页 PR 口径一致：按 historyKey 比最大重量）。
    private var personalRecords: [PersonalRecord] {
        historyStore.workoutRecords[workout.localId] ?? fallbackRecords ?? []
    }

    /// 命中 PR 的动作 → 该次最大重量。用于在对应顶组行打 ▲ PR 徽标。
    private var prMaxByKey: [String: Double] {
        var out: [String: Double] = [:]
        let prKeys = Set(personalRecords.map(\.exerciseKey))
        for ex in sortedExercises where prKeys.contains(ex.historyKey) {
            if let m = ex.sets.filter(\.countsForStats).compactMap(\.weightKg).max() { out[ex.historyKey] = m }
        }
        return out
    }

    // MARK: 派生统计（全部重算，不持久化）

    /// 已完成组数（口径与首页/记录中三联数一致：完成勾选的组）。
    private var completedSetCount: Int {
        workout.exercises.flatMap(\.sets).filter(\.completed).count
    }

    /// 训练量 kg·rep：完成组的 重量 × 次数 之和。
    private var totalVolume: Double {
        workout.exercises.flatMap(\.sets).reduce(0.0) { acc, s in
            guard s.completed, s.countsForStats, let w = s.weightKg, let r = s.reps else { return acc }
            return acc + w * Double(r)
        }
    }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    summaryCard
                    triadStats
                    if !personalRecords.isEmpty { prStrip }
                    logSection
                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.sm)
            }
        }
        // 子页统一导航栏：返回 + ⋯ 删除（双环处理收口在 paperToolbar）。
        .paperToolbar(title: workout.title ?? "训练", onBack: { dismiss() }) {
            CircleIconButton(systemName: "ellipsis", action: { confirmingDelete = true })
        }
        .paperConfirmDialog(
            isPresented: $confirmingDelete,
            title: "删除这次训练?",
            message: "记录将从列表移除并同步删除",
            confirmTitle: "删除",
            onConfirm: { deleteWorkout() }
        )
        .task(id: workout.localId) {
            WorkoutPerformanceMonitor.event("workout.detail.appear")
            if historyStore.workoutRecords[workout.localId] == nil {
                fallbackRecords = historyStore.lastRefreshFinishedAt == nil
                    ? computeFallbackRecords()
                    : []
            }
        }
    }

    // MARK: 完成头卡（替换记录中 REC 计时条）

    private var summaryCard: some View {
        HStack(spacing: Theme.Spacing.md) {
            dateBlock(workout.startedAt)
            VStack(alignment: .leading, spacing: 5) {
                Text(workout.title ?? "训练")
                    .font(Theme.Font.l2)
                    .foregroundStyle(Theme.Color.fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(rangeText)
                    .font(Theme.Font.mono(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Color.fg2)
                donePill
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(workout.title ?? "训练")，\(rangeText)，已完成")
    }

    /// 日期方块：日 + 「M月 · 周E」（沿用首页最近训练样式）。
    private func dateBlock(_ date: Date) -> some View {
        let cal = Calendar.current
        let day = cal.component(.day, from: date)
        let month = cal.component(.month, from: date)
        let weekday = Self.weekdayFormatter.string(from: date)
        return VStack(spacing: 2) {
            Text(String(format: "%02d", day)).numStyle(size: 21).foregroundStyle(Theme.Color.fg)
            Text("\(month)月 · \(weekday)")
                .font(Theme.Font.mono(size: 9, weight: .medium))
                .foregroundStyle(Theme.Color.muted)
        }
        .frame(width: 54, height: 54)
        .background(Theme.Color.bg, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(Theme.Color.border, lineWidth: 1))
    }

    /// 绿色「已完成」印（唯一非朱砂的状态色：表归档完成，不与行动红争夺）。
    private var donePill: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .heavy))
            Text("已完成")
                .font(Theme.Font.mono(size: 9.5, weight: .bold))
                .tracking(0.06 * 9.5)
        }
        .foregroundStyle(Theme.Color.ok)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(Theme.Color.ok.opacity(0.10), in: Capsule())
        .overlay(Capsule().stroke(Theme.Color.ok.opacity(0.22), lineWidth: 1))
    }

    /// 时段文案：`HH:mm – HH:mm`（无 endedAt 理论不会进入本页，兜底只显示开始）。
    private var rangeText: String {
        let start = Self.timeFormatter.string(from: workout.startedAt)
        guard let end = workout.endedAt else { return start }
        return "\(start) – \(Self.timeFormatter.string(from: end))"
    }

    // MARK: 三联数（时长 / 总组数 / 训练量，已完成口径，无「剩余动作」）

    private var triadStats: some View {
        HStack(spacing: 0) {
            triadCell(value: durationText, label: "时长", mono: true)
            divider
            triadCell(value: "\(completedSetCount)", label: "总组数", mono: false)
            divider
            triadCell(value: formatVolume(totalVolume), label: "训练量", mono: false)
        }
        .cardStyle(padding: 0)
        .frame(height: 76)
    }

    private func triadCell(value: String, label: String, mono: Bool) -> some View {
        VStack(spacing: 7) {
            Text(value)
                .font(mono ? Theme.Font.number(size: 19, weight: .bold)
                           : Theme.Font.display(size: 23, weight: .heavy))
                .foregroundStyle(Theme.Color.fg)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label).eyebrowStyle()
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(Theme.Color.border).frame(width: 1)
    }

    /// 时长：≥1 小时显示 `H:MM`，否则 `M′`。
    private var durationText: String {
        guard let end = workout.endedAt else { return "—" }
        let mins = max(0, Int(end.timeIntervalSince(workout.timerStartedAt ?? workout.startedAt) / 60))
        if mins >= 60 { return "\(mins / 60):" + String(format: "%02d", mins % 60) }
        return "\(mins)′"
    }

    private func formatVolume(_ v: Double) -> String {
        if v >= 1000 { return String(format: "%.1fk", v / 1000) }
        return String(format: "%.0f", v)
    }

    // MARK: PR 高光条（全屏唯一朱砂红高光；无 PR 时整条不出现）

    private var prStrip: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.Color.accent)
                Text(personalRecords.count == 1 ? "本次 1 项新纪录" : "本次 \(personalRecords.count) 项新纪录")
                    .font(Theme.Font.mono(size: 10, weight: .bold))
                    .tracking(0.1 * 10)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Color.accent)
            }
            VStack(spacing: 6) {
                ForEach(personalRecords) { pr in
                    HStack(alignment: .firstTextBaseline) {
                        Text(pr.exerciseName)
                            .font(Theme.Font.body(size: 12.5, weight: .semibold))
                            .foregroundStyle(Theme.Color.fg)
                        Spacer(minLength: Theme.Spacing.sm)
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text(formatKg(pr.weightKg))
                                .font(Theme.Font.number(size: 13, weight: .bold))
                                .foregroundStyle(Theme.Color.accent)
                            Text("kg")
                                .font(Theme.Font.mono(size: 9, weight: .semibold))
                                .foregroundStyle(Theme.Color.accent.opacity(0.7))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.accentSofter, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .stroke(Theme.Color.accent.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: 动作日志（全部展开的只读账本）

    private var logSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("动作日志 · \(sortedExercises.count)").eyebrowStyle()
            ForEach(sortedExercises) { ex in
                ExerciseLogCard(exercise: ex, prMaxWeight: prMaxByKey[ex.historyKey])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: actions

    private func deleteWorkout() {
        Theme.Haptics.impact(.rigid)
        workout.markDeleted()
        try? modelContext.save()
        historyStore.scheduleRefresh(reason: .workoutChanged, delayNanoseconds: 0)
        dismiss()
    }

    private func computeFallbackRecords() -> [PersonalRecord] {
        let startedAt = workout.startedAt
        let localId = workout.localId
        var descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate {
                $0.deletedAt == nil
                && $0.endedAt != nil
                && $0.startedAt < startedAt
                && $0.localId != localId
            },
            sortBy: [SortDescriptor(\.startedAt, order: .forward)]
        )
        descriptor.fetchLimit = 1_000
        let history = (try? modelContext.fetch(descriptor)) ?? []
        return detectPersonalRecords(in: workout, history: history)
    }
}

// MARK: - 单个动作的只读日志卡

private struct ExerciseLogCard: View {
    let exercise: WorkoutExercise
    /// 该动作本次的 PR 重量（非 nil 时，等于此重量的首个组标 ▲ PR）。
    var prMaxWeight: Double?
    @State private var showingFullNote = false

    private var sortedSets: [WorkoutSet] {
        exercise.displaySortedSets
    }
    /// 只读徽章：热身组 `W`；正式组按「仅正式组」展示序相对序号 1..n。
    private func badgeText(for set: WorkoutSet) -> String {
        if set.setType == .warmup { return "热" }
        var n = 0
        for s in sortedSets where s.setType != .warmup {
            n += 1
            if s.localId == set.localId { return "\(n)" }
        }
        return "\(n)"
    }

    /// 卡头聚合：`N 组 · X.Xk`（N=完成组，容量=完成组的 重量×次数）。
    private var aggText: String {
        let done = sortedSets.filter(\.completed)
        let count = done.isEmpty ? sortedSets.count : done.count
        let vol = (done.isEmpty ? sortedSets : done).reduce(0.0) { acc, s in
            guard s.countsForStats, let w = s.weightKg, let r = s.reps else { return acc }
            return acc + w * Double(r)
        }
        let volText = vol >= 1000 ? String(format: "%.1fk", vol / 1000) : String(format: "%.0f", vol)
        return vol > 0 ? "\(count) 组 · \(volText)" : "\(count) 组"
    }

    /// 命中 ▲ PR 的组下标（该动作命中 PR 时，重量等于 prMaxWeight 的首个组）。
    private var prSetIndex: Int? {
        guard let pr = prMaxWeight else { return nil }
        return sortedSets.first(where: { $0.weightKg == pr })?.setIndex
    }
    private var noteText: String? {
        let trimmed = exercise.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(exercise.displayExerciseName)
                    .font(Theme.Font.l2)
                    .foregroundStyle(Theme.Color.fg)
                Spacer()
                Text(aggText)
                    .font(Theme.Font.mono(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Color.muted)
            }
            .padding(.horizontal, 15)
            .padding(.top, 12).padding(.bottom, 10)

            if let noteText {
                Button {
                    showingFullNote = true
                } label: {
                    notePreview(noteText)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 15)
                .padding(.bottom, 10)
                .accessibilityLabel("查看动作备注")
                .accessibilityHint(noteText)
            }

            Rectangle().fill(Theme.Color.border).frame(height: 1).padding(.horizontal, 15)

            VStack(spacing: 0) {
                ForEach(Array(sortedSets.enumerated()), id: \.element.localId) { idx, set in
                    if idx > 0 {
                        Rectangle().fill(Theme.Color.border.opacity(0.55)).frame(height: 1)
                            .padding(.horizontal, 15)
                    }
                    LogSetRow(set: set, badgeText: badgeText(for: set), isPR: set.setIndex == prSetIndex)
                }
            }
            .padding(.vertical, 3)
        }
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .stroke(Theme.Color.border, lineWidth: 1)
        )
        .paperShadow(.sm, cornerRadius: Theme.Radius.lg)
        .sheet(isPresented: $showingFullNote) {
            if let noteText {
                ExerciseFullNoteSheet(exerciseName: exercise.displayExerciseName, note: noteText)
            }
        }
    }

    private func notePreview(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "note.text")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Color.fg2)
                .padding(.top, 2)
            Text(text)
                .font(Theme.Font.body(size: 13, weight: .medium))
                .foregroundStyle(Theme.Color.fg2)
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(Theme.Color.bg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.Color.border, lineWidth: 1)
        )
    }
}

private struct ExerciseFullNoteSheet: View {
    let exerciseName: String
    let note: String

    var body: some View {
        VStack(spacing: 0) {
            PaperSheetTitleHeader(title: "动作备注", background: Theme.Color.surface)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(exerciseName)
                        .font(Theme.Font.l2)
                        .foregroundStyle(Theme.Color.fg)
                        .lineLimit(2)

                    Text(note)
                        .font(Theme.Font.body(size: 15, weight: .medium))
                        .foregroundStyle(Theme.Color.fg2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Theme.Color.bg, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .stroke(Theme.Color.border, lineWidth: 1)
                        )
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .background(Theme.Color.surface.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - 只读账本行：[组号][重量 × 次数][▲PR?]，无输入框、无勾选

private struct LogSetRow: View {
    let set: WorkoutSet
    /// 序号徽章：热身组 `W`，正式组相对序号。
    var badgeText: String = ""
    var isPR: Bool = false

    /// 缺值（未填重量/次数且未完成）视为略过组，整行降灰。
    private var isSkipped: Bool {
        !set.completed && set.weightKg == nil && set.reps == nil
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(badgeText)
                .font(Theme.Font.mono(size: 11, weight: .bold))
                .foregroundStyle(set.setType == .warmup ? Theme.Color.accent : Theme.Color.muted)
                .frame(width: 22, height: 18)
                .background(set.setType == .warmup ? Theme.Color.accentSoft : Color.clear,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(set.weightKg.map(formatKg) ?? "—")
                    .font(Theme.Font.number(size: 15, weight: .bold))
                    .foregroundStyle(valueColor)
                Text("kg")
                    .font(Theme.Font.mono(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.Color.muted)
                    .padding(.trailing, 5)
                Text("×")
                    .font(Theme.Font.mono(size: 11))
                    .foregroundStyle(Theme.Color.muted)
                    .padding(.trailing, 5)
                Text(set.reps.map(String.init) ?? "—")
                    .font(Theme.Font.number(size: 15, weight: .bold))
                    .foregroundStyle(valueColor)
                Text("次")
                    .font(Theme.Font.mono(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.Color.muted)
            }

            Spacer(minLength: 0)

            if isPR { prTag }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
    }

    private var valueColor: Color {
        if isSkipped { return Theme.Color.muted }
        return isPR ? Theme.Color.accent : Theme.Color.fg
    }

    private var prTag: some View {
        HStack(spacing: 3) {
            Image(systemName: "arrowtriangle.up.fill").font(.system(size: 7, weight: .bold))
            Text("PR").font(Theme.Font.mono(size: 9, weight: .bold)).tracking(0.04 * 9)
        }
        .foregroundStyle(Theme.Color.accent)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Theme.Color.accentSofter, in: Capsule())
        .overlay(Capsule().stroke(Theme.Color.accent.opacity(0.18), lineWidth: 1))
    }

    private var a11yLabel: String {
        let w = set.weightKg.map { "\(formatKg($0)) 公斤" } ?? "未记录重量"
        let r = set.reps.map { "\($0) 次" } ?? "未记录次数"
        let name = set.setType == .warmup ? "热身组" : "第 \(badgeText) 组"
        return "\(name)，\(w)，\(r)" + (isPR ? "，新纪录" : "")
    }
}
