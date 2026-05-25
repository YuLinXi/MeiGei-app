import SwiftUI
import SwiftData

/// 选择动作的结果：内置 code 或自定义 id 二选一。
struct ExercisePick: Identifiable, Hashable {
    var builtinCode: String?
    var customId: UUID?
    var name: String
    var primaryMuscle: String?
    var id: String { builtinCode ?? customId?.uuidString ?? name }
}

/// 动作列表的筛选/搜索。返回内置 + 自定义两段结果（保留来源以打标）。
func filterExercises(
    builtin: [BuiltinExercise],
    custom: [CustomExercise],
    query: String,
    muscle: MuscleGroup?
) -> (builtin: [BuiltinExercise], custom: [CustomExercise]) {
    let q = query.trimmingCharacters(in: .whitespaces)
    func matchMuscle(_ m: String?) -> Bool { muscle == nil || m == muscle?.rawValue }
    func matchQuery(_ name: String) -> Bool { q.isEmpty || name.localizedCaseInsensitiveContains(q) }
    let b = builtin.filter { matchMuscle($0.primaryMuscle) && matchQuery($0.name) }
    let c = custom.filter { $0.deletedAt == nil && matchMuscle($0.primaryMuscle) && matchQuery($0.name) }
    return (b, c)
}

// MARK: - 3.4 动作库

/// 动作库：浏览 / 按肌群筛选 / 搜索 + 自定义动作创建。
struct ExerciseLibraryView: View {
    @Query(sort: \CustomExercise.updatedAt, order: .reverse) private var custom: [CustomExercise]
    @State private var query = ""
    @State private var muscle: MuscleGroup?
    @State private var showingCreate = false

    var body: some View {
        let result = filterExercises(builtin: BuiltinExercise.starter, custom: custom, query: query, muscle: muscle)
        List {
            if !result.custom.isEmpty {
                Section("个人") {
                    ForEach(result.custom) { ex in
                        ExerciseRow(name: ex.name, muscle: ex.primaryMuscle, equipment: ex.equipmentType, isCustom: true)
                    }
                }
            }
            Section("标准库") {
                ForEach(result.builtin) { ex in
                    NavigationLink(value: ex) {
                        ExerciseRow(name: ex.name, muscle: ex.primaryMuscle, equipment: ex.equipmentType, isCustom: false)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Color.bg)
        .searchable(text: $query, prompt: "搜索动作")
        .navigationTitle("动作库")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { muscleFilter }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingCreate) { CustomExerciseEditorView() }
        .navigationDestination(for: BuiltinExercise.self) { ExerciseDetailView(exercise: $0) }
    }

    private var muscleFilter: some View {
        Menu {
            Button("全部部位") { muscle = nil }
            ForEach(MuscleGroup.allCases) { m in
                Button(m.rawValue) { muscle = m }
            }
        } label: {
            Label(muscle?.rawValue ?? "部位", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
}

private struct ExerciseRow: View {
    let name: String
    let muscle: String?
    let equipment: String?
    let isCustom: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                if let detail = [muscle, equipment].compactMap({ $0 }).joined(separator: " · ").nilIfEmpty {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isCustom {
                Text("个人").font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.tint.opacity(0.15)).clipShape(Capsule())
            }
        }
    }
}

// MARK: - 自定义动作创建

struct CustomExerciseEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var muscle: MuscleGroup = .chest
    @State private var equipment: EquipmentType = .barbell

    var body: some View {
        NavigationStack {
            Form {
                TextField("动作名称", text: $name)
                Picker("主要肌群", selection: $muscle) {
                    ForEach(MuscleGroup.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("器械", selection: $equipment) {
                    ForEach(EquipmentType.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            .navigationTitle("新建动作")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let ex = CustomExercise(name: name.trimmingCharacters(in: .whitespaces),
                                primaryMuscle: muscle.rawValue, equipmentType: equipment.rawValue)
        modelContext.insert(ex)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - 动作选择器（供计划/训练添加动作复用）

struct ExercisePickerView: View {
    @Query(sort: \CustomExercise.updatedAt, order: .reverse) private var custom: [CustomExercise]
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var muscle: MuscleGroup?
    let onPick: (ExercisePick) -> Void

    var body: some View {
        NavigationStack {
            let result = filterExercises(builtin: BuiltinExercise.starter, custom: custom, query: query, muscle: muscle)
            List {
                if !result.custom.isEmpty {
                    Section("个人") {
                        ForEach(result.custom) { ex in
                            Button { pick(custom: ex) } label: {
                                ExerciseRow(name: ex.name, muscle: ex.primaryMuscle, equipment: ex.equipmentType, isCustom: true)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Section("标准库") {
                    ForEach(result.builtin) { ex in
                        Button { pick(builtin: ex) } label: {
                            ExerciseRow(name: ex.name, muscle: ex.primaryMuscle, equipment: ex.equipmentType, isCustom: false)
                        }.buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $query, prompt: "搜索动作")
            .navigationTitle("选择动作")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("全部部位") { muscle = nil }
                        ForEach(MuscleGroup.allCases) { m in Button(m.rawValue) { muscle = m } }
                    } label: { Label(muscle?.rawValue ?? "部位", systemImage: "line.3.horizontal.decrease.circle") }
                }
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
    }

    private func pick(builtin ex: BuiltinExercise) {
        onPick(ExercisePick(builtinCode: ex.code, customId: nil, name: ex.name, primaryMuscle: ex.primaryMuscle))
        dismiss()
    }
    private func pick(custom ex: CustomExercise) {
        onPick(ExercisePick(builtinCode: nil, customId: ex.localId, name: ex.name, primaryMuscle: ex.primaryMuscle))
        dismiss()
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - 动作详情（设计稿 03）

struct ExerciseDetailView: View {
    let exercise: BuiltinExercise
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Workout> { $0.deletedAt == nil },
           sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]

    /// 本动作历史所有 (重量, 次数, 日期)。
    private struct Entry { let weight: Double; let reps: Int; let date: Date }
    private var entries: [Entry] {
        var out: [Entry] = []
        for w in workouts where w.deletedAt == nil && w.endedAt != nil {
            for ex in w.exercises where ex.builtinExerciseCode == exercise.code {
                for s in ex.sets {
                    if let wt = s.weightKg, let r = s.reps, r > 0 {
                        out.append(Entry(weight: wt, reps: r, date: w.startedAt))
                    }
                }
            }
        }
        return out
    }
    /// 当前 PR：本动作历史最大重量；返回 (重量, 次数, 日期)。
    private var currentPR: Entry? {
        entries.max(by: { $0.weight < $1.weight })
    }
    /// 历史第二高 PR 的重量（不同日期的次高，用来算「较上次 PR +X」差值）。
    private var secondBestKg: Double? {
        guard let pr = currentPR else { return nil }
        let others = entries.filter { !Calendar.current.isDate($0.date, inSameDayAs: pr.date) }
        return others.map(\.weight).max()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Color.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    cover
                    title
                    if currentPR != nil { prCard }
                    OneRepMaxChart(workouts: workouts, exerciseKey: exercise.code)
                    tipsCard
                    musclesCard
                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }
            joinCTA
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // 顶部 cover：渐变 + 部位文字
    private var cover: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [Theme.Color.surface, Theme.Color.bg],
                           startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                Text("MUSCLE · 部位").eyebrowStyle()
                Text(exercise.primaryMuscle)
                    .font(Theme.Font.display(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg2)
            }
            .padding(Theme.Spacing.md)
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.Color.border, lineWidth: 1))
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise.name)
                .font(Theme.Font.display(size: 28, weight: .bold))
                .foregroundStyle(Theme.Color.fg)
            Text(exercise.code)
                .font(Theme.Font.mono(size: 13, weight: .regular))
                .foregroundStyle(Theme.Color.muted)
            Text("\(exercise.primaryMuscle) · \(exercise.equipmentType)")
                .eyebrowStyle()
        }
    }

    private var prCard: some View {
        let pr = currentPR!
        let dateStr = pr.date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        let diffStr: String? = {
            guard let sec = secondBestKg, sec < pr.weight else { return nil }
            return "较上次 PR +\(formatKg(pr.weight - sec))kg"
        }()
        return HStack(spacing: 0) {
            Rectangle().fill(Theme.Color.accentMagenta).frame(width: 3)
            VStack(alignment: .leading, spacing: 8) {
                Text("★ PERSONAL RECORD")
                    .font(Theme.Font.mono(size: 10, weight: .semibold))
                    .tracking(0.08 * 10).textCase(.uppercase)
                    .foregroundStyle(Theme.Color.accentMagenta)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(formatKg(pr.weight)).numStyle(size: 32).foregroundStyle(Theme.Color.fg)
                    Text("kg").numStyle(size: 14).foregroundStyle(Theme.Color.fg2)
                    Text("× \(pr.reps)").numStyle(size: 18).foregroundStyle(Theme.Color.fg2)
                }
                Text("\(dateStr)" + (diffStr.map { " · \($0)" } ?? ""))
                    .font(Theme.Font.body(size: 12))
                    .foregroundStyle(Theme.Color.fg2)
            }
            .padding(Theme.Spacing.md)
            Spacer()
        }
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Theme.Color.accentMagenta.opacity(0.45), lineWidth: 1)
        )
        .neonGlow(.magenta, intensity: .sm, cornerRadius: Theme.Radius.md)
    }

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("FORM · 动作要点").eyebrowStyle()
            // BuiltinExercise 暂无 tip 字段（任务 3.1 数据工程未完成），统一占位。
            Text("暂无要点 · 数据采集中")
                .font(Theme.Font.body(size: 13))
                .foregroundStyle(Theme.Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var musclesCard: some View {
        HStack(spacing: Theme.Spacing.md) {
            muscleColumn(title: "PRIMARY · 主动肌", value: exercise.primaryMuscle)
            muscleColumn(title: "SYNERGISTS · 协同", value: "—")
        }
    }

    private func muscleColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).eyebrowStyle()
            Text(value)
                .font(Theme.Font.body(size: 15, weight: .semibold))
                .foregroundStyle(value == "—" ? Theme.Color.muted : Theme.Color.fg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var joinCTA: some View {
        Button { addToTodayWorkout() } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("加入今日训练")
            }
            .font(Theme.Font.body(size: 16, weight: .semibold))
            .foregroundStyle(Theme.Color.bg)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(Theme.Color.accentCyan, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .neonGlow(.cyan, intensity: .medium, cornerRadius: Theme.Radius.md)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, 16)
    }

    /// 找当前进行中的训练（endedAt == nil）：有则 append 动作，无则新建。
    private func addToTodayWorkout() {
        let active = workouts.first(where: { $0.endedAt == nil && $0.deletedAt == nil })
        let target = active ?? {
            let w = Workout(title: "训练")
            modelContext.insert(w)
            return w
        }()
        let ex = WorkoutExercise(builtinExerciseCode: exercise.code,
                                 customExerciseId: nil,
                                 exerciseName: exercise.name,
                                 primaryMuscle: exercise.primaryMuscle,
                                 orderIndex: target.exercises.count)
        ex.sets = [WorkoutSet(setIndex: 0)]
        target.exercises.append(ex)
        target.markDirty()
        try? modelContext.save()
        dismiss()
    }
}
