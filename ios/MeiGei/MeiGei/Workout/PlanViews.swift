import SwiftUI
import SwiftData
import OSLog

// MARK: - 计划列表（Screen 05，Neon 改版）

/// 计划列表：「进行中」featured 卡 + 「我的计划」+ 「推荐模板」三段。
struct PlanListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<WorkoutPlan> { $0.deletedAt == nil },
           sort: \WorkoutPlan.updatedAt, order: .reverse)
    private var plans: [WorkoutPlan]
    @Query(filter: #Predicate<Workout> { $0.deletedAt == nil },
           sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]
    @State private var creatingNew = false

    /// 「进行中」= 最近 14 天内有 workout 关联 planId 的计划；
    /// 否则取最近更新的一个；若无任何计划则为 nil。判定逻辑复用 `WorkoutPlan.active`，与首页一致。
    private var activePlan: WorkoutPlan? {
        WorkoutPlan.active(in: plans, workouts: workouts)
    }

    private var otherPlans: [WorkoutPlan] {
        guard let active = activePlan else { return plans }
        return plans.filter { $0.localId != active.localId }
    }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if let active = activePlan {
                        Text("进行中").eyebrowStyle()
                        featuredCard(active)
                    }

                    Text("我的计划").eyebrowStyle()
                    if otherPlans.isEmpty {
                        emptyMineCard
                    } else {
                        VStack(spacing: Theme.Spacing.md) {
                            ForEach(otherPlans) { plan in
                                NavigationLink(value: plan) { planCard(plan) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }

                    Text("推荐模板").eyebrowStyle()
                    recommendedCard

                    Color.clear.frame(height: 32)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }
        }
        .navigationTitle("计划")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creatingNew = true } label: {
                    Image(systemName: "plus").foregroundStyle(Theme.Color.fg)
                }
            }
        }
        .navigationDestination(for: WorkoutPlan.self) { PlanDetailView(plan: $0) }
        .navigationDestination(isPresented: $creatingNew) {
            PlanEditorView(plan: nil)
        }
    }

    @ViewBuilder
    private func featuredCard(_ plan: WorkoutPlan) -> some View {
        let n = workouts.filter { $0.planId == plan.localId && $0.endedAt != nil }.count
        let total = max(8, n + 4)
        NavigationLink(value: plan) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    Text("WEEK \(min(n, total)) / \(total)")
                        .font(Theme.Font.mono(size: 11, weight: .semibold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Theme.Color.bg.opacity(0.35), in: Capsule())
                        .foregroundStyle(Theme.Color.fg)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Theme.Color.fg)
                }
                Text(plan.name)
                    .font(Theme.Font.display(size: 26, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                Text("\(plan.items.count) 个动作 · 严肃推/拉/腿循环")
                    .font(Theme.Font.body(size: 13))
                    .foregroundStyle(Theme.Color.fg.opacity(0.85))
                HStack(spacing: Theme.Spacing.xl) {
                    metaCol(title: "已完成", value: "\(n)")
                    metaCol(title: "剩余",   value: "\(max(0, total - n))")
                    metaCol(title: "次/周", value: "3")
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Theme.Color.accentCyan, Theme.Color.surface],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: Theme.Radius.lg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(Theme.Color.accentCyan.opacity(0.5), lineWidth: 1)
            )
            .neonGlow(.cyan, intensity: .medium, cornerRadius: Theme.Radius.lg)
        }
        .buttonStyle(.plain)
    }

    private func metaCol(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).eyebrowStyle().foregroundStyle(Theme.Color.fg.opacity(0.7))
            Text(value).numStyle(size: 18).foregroundStyle(Theme.Color.fg)
        }
    }

    private func planCard(_ plan: WorkoutPlan) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.name)
                    .font(Theme.Font.body(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                Text("\(plan.items.count) 个动作 · \(plan.updatedAt.formatted(.relative(presentation: .named)))")
                    .font(Theme.Font.mono(size: 11))
                    .foregroundStyle(Theme.Color.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var emptyMineCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("还没有计划")
                .font(Theme.Font.body(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
            Text("点右上 + 新建一个训练模板")
                .font(Theme.Font.body(size: 13))
                .foregroundStyle(Theme.Color.fg2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var recommendedCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PPL · 推/拉/腿 6 周").font(Theme.Font.body(size: 15, weight: .semibold)).foregroundStyle(Theme.Color.fg)
            Text("即将上线 · 数据采集中").font(Theme.Font.mono(size: 11)).foregroundStyle(Theme.Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .opacity(0.6)
    }
}

// MARK: - 计划详情（Screen 06，Neon 改版）

struct PlanDetailView: View {
    @Bindable var plan: WorkoutPlan
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var pickingExercise = false
    @State private var editingItem: PlanItem?
    @State private var editing = false
    @State private var decodeError: String?
    /// 单一活跃会话守卫：冲突态 + 待新建闭包 + 导航打开的会话。
    @State private var conflict: Workout?
    @State private var pendingBuild: (() -> Workout)?
    @State private var startedSession: Workout?

    private static let log = Logger(subsystem: "com.yulinxi.app.MeiGei", category: "PlanDetail")

    private var orderedItems: [PlanItem] {
        plan.items.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var totalSets: Int {
        plan.items.reduce(0) { $0 + ($1.suggestedSets ?? 0) }
    }

    /// 粗估时长：组数 × (40s 训练 + 90s 休息) / 60。
    private var estimatedMinutes: Int {
        max(15, totalSets * 130 / 60)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Color.bg.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    header
                    metaRow

                    if let err = decodeError {
                        decodeErrorCard(err)
                    } else if orderedItems.isEmpty {
                        emptyExercisesCard
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(orderedItems.enumerated()), id: \.element.itemId) { idx, item in
                                row(index: idx + 1, item: item)
                                if idx < orderedItems.count - 1 {
                                    Rectangle().fill(Theme.Color.border).frame(height: 1).padding(.leading, 56)
                                }
                            }
                        }
                        .cardStyle(padding: 0)
                    }

                    addExerciseCTA
                    Color.clear.frame(height: 120)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }
            bottomBar
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("编辑名称…") { editing = true }
                    Button("删除计划", role: .destructive) { delete() }
                } label: {
                    Image(systemName: "ellipsis").foregroundStyle(Theme.Color.fg)
                }
            }
        }
        .sheet(isPresented: $pickingExercise) {
            ExercisePickerView { pick in
                var items = plan.items
                items.append(PlanItem(builtinExerciseCode: pick.builtinCode, customExerciseId: pick.customId,
                                      exerciseName: pick.name, orderIndex: items.count))
                plan.items = items
                plan.markDirty()
                try? modelContext.save()
            }
        }
        .sheet(item: $editingItem) { item in
            PlanItemEditorView(item: item) { updated in
                var items = plan.items
                if let idx = items.firstIndex(where: { $0.itemId == updated.itemId }) {
                    items[idx] = updated
                    plan.items = items
                    plan.markDirty()
                    try? modelContext.save()
                }
            }
        }
        .sheet(isPresented: $editing) {
            PlanRenameSheet(plan: plan)
        }
        .navigationDestination(item: $startedSession) { WorkoutLoggingView(workout: $0) }
        .confirmationDialog("已有进行中的训练", isPresented: Binding(
            get: { conflict != nil },
            set: { if !$0 { conflict = nil; pendingBuild = nil } }), presenting: conflict) { existing in
            Button("继续训练") { startedSession = existing; pendingBuild = nil }
            Button("丢弃并开始新训练", role: .destructive) {
                WorkoutSession.discard(existing, in: modelContext)
                if let build = pendingBuild { commit(build) }
                pendingBuild = nil
            }
            Button("取消", role: .cancel) { pendingBuild = nil }
        } message: { _ in Text("同一时间只能有一个进行中的训练。继续既有训练，或丢弃后开始新的。") }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("PLAN · 训练模板").eyebrowStyle()
            Text(plan.name)
                .font(Theme.Font.display(size: 30, weight: .bold))
                .foregroundStyle(Theme.Color.fg)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var metaRow: some View {
        HStack(spacing: Theme.Spacing.xl) {
            metaCol("动作", "\(plan.items.count)")
            metaCol("组数", "\(totalSets)")
            metaCol("时长", "≈\(estimatedMinutes) 分")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func metaCol(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).eyebrowStyle()
            Text(value).numStyle(size: 20).foregroundStyle(Theme.Color.fg)
        }
    }

    private func row(index: Int, item: PlanItem) -> some View {
        Button { editingItem = item } label: {
            HStack(spacing: Theme.Spacing.md) {
                Text(String(format: "%02d", index))
                    .numStyle(size: 18)
                    .foregroundStyle(Theme.Color.accentCyan)
                    .frame(width: 28, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.exerciseName)
                        .font(Theme.Font.body(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Color.fg)
                    Text(subtitle(item))
                        .font(Theme.Font.mono(size: 11))
                        .foregroundStyle(Theme.Color.muted)
                }
                Spacer()
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(Theme.Color.muted)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .frame(minHeight: 60)
        }
        .buttonStyle(.plain)
    }

    private var emptyExercisesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("还没有动作")
                .font(Theme.Font.body(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
            Text("点下方「+ 添加动作」开始编排")
                .font(Theme.Font.body(size: 13))
                .foregroundStyle(Theme.Color.fg2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var addExerciseCTA: some View {
        Button { pickingExercise = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                Text("添加动作")
            }
            .font(Theme.Font.body(size: 14, weight: .semibold))
            .foregroundStyle(Theme.Color.accentCyan)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Theme.Color.bg, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .strokeBorder(Theme.Color.border, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            )
        }
        .buttonStyle(.plain)
    }

    /// jsonb 解码错误兜底卡（design.md D3）：当 SwiftData 反序列化 items 异常时显示。
    /// 实际 SwiftData 走 Codable，解码失败会在底层抛错；这里保留 UI 钩子方便未来 catch。
    private func decodeErrorCard(_ err: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("PLAN · ERROR").eyebrowStyle().foregroundStyle(Theme.Color.danger)
            Text("计划数据损坏，请重建")
                .font(Theme.Font.body(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Color.danger)
            Text(err)
                .font(Theme.Font.mono(size: 11))
                .foregroundStyle(Theme.Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Theme.Color.danger.opacity(0.55), lineWidth: 1)
        )
    }

    private var bottomBar: some View {
        HStack(spacing: Theme.Spacing.md) {
            Button { duplicate() } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg2)
                    .frame(width: 50, height: 50)
                    .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.Color.border, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button { startWorkout() } label: {
                HStack(spacing: 6) {
                    Text("开始这次训练")
                    Image(systemName: "arrow.right")
                }
                .font(Theme.Font.body(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Color.bg)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Theme.Color.accentCyan, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
            .buttonStyle(.plain)
            .neonGlow(.cyan, intensity: .medium, cornerRadius: Theme.Radius.md)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
        .background(
            LinearGradient(
                colors: [Theme.Color.bg.opacity(0), Theme.Color.bg, Theme.Color.bg],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    private func subtitle(_ item: PlanItem) -> String {
        var parts: [String] = []
        if let s = item.suggestedSets, let r = item.suggestedReps { parts.append("\(s)组 × \(r)次") }
        else if let s = item.suggestedSets { parts.append("\(s)组") }
        if let w = item.suggestedWeightKg { parts.append("\(formatKg(w)) kg") }
        return parts.isEmpty ? "未设建议" : parts.joined(separator: " · ")
    }

    private func duplicate() {
        let copy = WorkoutPlan(name: plan.name + " · 副本",
                               items: plan.items.map {
                                   PlanItem(itemId: UUID(),
                                            builtinExerciseCode: $0.builtinExerciseCode,
                                            customExerciseId: $0.customExerciseId,
                                            exerciseName: $0.exerciseName,
                                            orderIndex: $0.orderIndex,
                                            suggestedSets: $0.suggestedSets,
                                            suggestedReps: $0.suggestedReps,
                                            suggestedWeightKg: $0.suggestedWeightKg)
                               },
                               forkedFrom: plan.localId)
        modelContext.insert(copy)
        try? modelContext.save()
    }

    /// 单一活跃会话守卫：存在进行中会话时弹「继续 / 丢弃」，否则新建并进入。
    private func startWorkout() {
        if let existing = WorkoutSession.activeSession(in: modelContext) {
            pendingBuild = buildFromPlan
            conflict = existing
        } else {
            commit(buildFromPlan)
        }
    }

    private func buildFromPlan() -> Workout {
        let w = Workout(planId: plan.localId, title: plan.name)
        for (i, item) in orderedItems.enumerated() {
            let ex = WorkoutExercise(
                builtinExerciseCode: item.builtinExerciseCode,
                customExerciseId: item.customExerciseId,
                exerciseName: item.exerciseName,
                orderIndex: i
            )
            let count = max(1, item.suggestedSets ?? 3)
            ex.sets = (0..<count).map { idx in WorkoutSet(setIndex: idx) }
            w.exercises.append(ex)
        }
        return w
    }

    private func commit(_ build: () -> Workout) {
        let w = build()
        modelContext.insert(w)
        try? modelContext.save()
        startedSession = w
    }

    private func delete() {
        plan.markDeleted()
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - 计划编辑器（仅用于新建空模板入口；详情页内联编辑动作项）

struct PlanEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let existing: WorkoutPlan?
    @State private var name: String

    init(plan: WorkoutPlan?) {
        self.existing = plan
        _name = State(initialValue: plan?.name ?? "")
    }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("CREATE · 新建计划").eyebrowStyle()
                TextField("", text: $name, prompt: Text("计划名称").foregroundColor(Theme.Color.muted))
                    .font(Theme.Font.display(size: 24, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.Color.border, lineWidth: 1))
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.md)
        }
        .navigationTitle(existing == nil ? "新建计划" : "编辑计划")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .tint(Theme.Color.accentCyan)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let existing {
            existing.name = trimmed
            existing.markDirty()
        } else {
            let plan = WorkoutPlan(name: trimmed)
            modelContext.insert(plan)
        }
        try? modelContext.save()
        dismiss()
    }
}

/// 重命名 sheet（PlanDetailView 三点菜单触发）。
struct PlanRenameSheet: View {
    @Bindable var plan: WorkoutPlan
    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(plan: WorkoutPlan) {
        self.plan = plan
        _name = State(initialValue: plan.name)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Color.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text("RENAME").eyebrowStyle()
                    TextField("", text: $name)
                        .font(Theme.Font.display(size: 22, weight: .bold))
                        .foregroundStyle(Theme.Color.fg)
                        .padding(Theme.Spacing.md)
                        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.Color.border, lineWidth: 1))
                    Spacer()
                }
                .padding(Theme.Spacing.lg)
            }
            .navigationTitle("重命名")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        plan.name = name.trimmingCharacters(in: .whitespaces)
                        plan.markDirty()
                        dismiss()
                    }
                    .tint(Theme.Color.accentCyan)
                }
            }
        }
    }
}

// MARK: - 单个动作项的建议参数编辑（保留原 Form，sheet 内）

struct PlanItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sets: Int
    @State private var reps: Int
    @State private var weight: String
    private let original: PlanItem
    let onSave: (PlanItem) -> Void

    init(item: PlanItem, onSave: @escaping (PlanItem) -> Void) {
        self.original = item
        self.onSave = onSave
        _sets = State(initialValue: item.suggestedSets ?? 3)
        _reps = State(initialValue: item.suggestedReps ?? 10)
        _weight = State(initialValue: item.suggestedWeightKg.map { formatKg($0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            // 必要的 Form 用法：动作建议是 sheet 内编辑表单，原生 Stepper/decimalPad
            // 在自绘容器内体验差，sheet 隔离视觉范围有限，保留 Form 并把背景压成 bg。
            Form {
                Section(original.exerciseName) {
                    Stepper("建议组数：\(sets)", value: $sets, in: 1...20)
                    Stepper("建议次数：\(reps)", value: $reps, in: 1...100)
                    HStack {
                        Text("建议重量(kg)")
                        TextField("可空", text: $weight).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Color.bg)
            .navigationTitle("动作建议")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        var updated = original
                        updated.suggestedSets = sets
                        updated.suggestedReps = reps
                        updated.suggestedWeightKg = Double(weight.replacingOccurrences(of: ",", with: "."))
                        onSave(updated)
                        dismiss()
                    }
                    .tint(Theme.Color.accentCyan)
                }
            }
        }
    }
}

/// 去掉多余小数（80.0 → "80"，72.5 → "72.5"）。
func formatKg(_ value: Double) -> String {
    value == value.rounded() ? String(Int(value)) : String(value)
}
