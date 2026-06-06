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

// MARK: - 3.4 动作库（Screen 04，Neon 改版）

/// 动作库筛选 chip 项。
struct LibraryChip: Identifiable, Hashable {
    let id: String
    let title: String
    let muscle: MuscleGroup?  // nil = 全部
}

/// 动作分组（复合 推 / 拉 / 腿 + 单关节）。
private enum LibraryGroup: String, CaseIterable {
    case push = "复合 · 推"
    case pull = "复合 · 拉"
    case leg  = "复合 · 腿"
    case iso  = "单关节"

    static func classify(_ code: String) -> LibraryGroup {
        switch code {
        case "BB_BENCH_PRESS", "DB_BENCH_PRESS", "INCLINE_BB_PRESS", "PUSH_UP",
             "OHP", "DB_SHOULDER_PRESS":
            return .push
        case "PULL_UP", "BB_ROW", "LAT_PULLDOWN", "DEADLIFT", "SEATED_CABLE_ROW", "FACE_PULL":
            return .pull
        case "BB_SQUAT", "LEG_PRESS", "ROMANIAN_DL", "HIP_THRUST":
            return .leg
        default:
            return .iso
        }
    }
}

/// 动作库：搜索 noop + 部位 chip + 分组列表 + PR 副标。
struct ExerciseLibraryView: View {
    @Query(sort: \CustomExercise.updatedAt, order: .reverse) private var custom: [CustomExercise]
    @Query(filter: #Predicate<Workout> { $0.deletedAt == nil },
           sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]

    @State private var query = ""
    @State private var muscle: String = "all"
    @State private var showingCreate = false

    private let chips: [LibraryChip] = [
        LibraryChip(id: "all",      title: "全部", muscle: nil),
        LibraryChip(id: "chest",    title: "胸",   muscle: .chest),
        LibraryChip(id: "back",     title: "背",   muscle: .back),
        LibraryChip(id: "leg",      title: "腿",   muscle: .legs),
        LibraryChip(id: "shoulder", title: "肩",   muscle: .shoulders),
        LibraryChip(id: "arm",      title: "手臂", muscle: .arms),
        LibraryChip(id: "core",     title: "核心", muscle: .core),
    ]

    private var selectedMuscle: MuscleGroup? {
        chips.first(where: { $0.id == muscle })?.muscle
    }

    private var builtinFiltered: [BuiltinExercise] {
        BuiltinExercise.starter.filter { ex in
            (selectedMuscle == nil || ex.primaryMuscle == selectedMuscle?.rawValue)
        }
    }

    private var customFiltered: [CustomExercise] {
        custom.filter { ex in
            ex.deletedAt == nil
                && (selectedMuscle == nil || ex.primaryMuscle == selectedMuscle?.rawValue)
        }
    }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg, pinnedViews: []) {
                    searchBar
                    HorizontalChipPicker(items: chips, selection: $muscle) { $0.title }
                        .padding(.horizontal, -Theme.Spacing.lg)

                    if builtinFiltered.isEmpty && customFiltered.isEmpty {
                        emptyState
                    } else {
                        groupedList
                    }
                    Color.clear.frame(height: 32)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }
        }
        .navigationTitle("动作")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingCreate = true } label: {
                    Image(systemName: "plus").foregroundStyle(Theme.Color.fg)
                }
            }
        }
        .sheet(isPresented: $showingCreate) { CustomExerciseEditorView() }
        .navigationDestination(for: BuiltinExercise.self) { ExerciseDetailView(exercise: $0) }
    }

    // 搜索框（noop，仅占位）
    private var searchBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.Color.muted)
            TextField("", text: $query, prompt: Text("搜索 \(BuiltinExercise.starter.count + custom.count) 个动作").foregroundColor(Theme.Color.muted))
                .font(Theme.Font.body(size: 14))
                .foregroundStyle(Theme.Color.fg)
                .submitLabel(.search)
                .disabled(true) // 真实搜索留到后续 change
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: 40)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.Color.border, lineWidth: 1))
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("EMPTY · 动作库").eyebrowStyle()
            Text("动作库尚未采集")
                .font(Theme.Font.display(size: 20, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
            Text("内置 150+ 动作正在补齐中。\n点击右上 + 添加自定义动作。")
                .font(Theme.Font.body(size: 13))
                .foregroundStyle(Theme.Color.fg2)
            Button { showingCreate = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("添加自定义动作")
                }
                .font(Theme.Font.body(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Color.bg)
                .padding(.horizontal, Theme.Spacing.lg)
                .frame(height: 40)
                .background(Theme.Color.accentCyan, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
            .buttonStyle(.plain)
            .neonGlow(.cyan, intensity: .sm, cornerRadius: Theme.Radius.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @ViewBuilder
    private var groupedList: some View {
        // 内置按分组拆分
        let grouped = Dictionary(grouping: builtinFiltered) { LibraryGroup.classify($0.code) }
        let orderedGroups: [LibraryGroup] = LibraryGroup.allCases.filter { grouped[$0]?.isEmpty == false }

        if !customFiltered.isEmpty {
            sectionHeader("我的 · 自定义")
            VStack(spacing: 0) {
                ForEach(Array(customFiltered.enumerated()), id: \.element.localId) { idx, ex in
                    customRow(ex)
                    if idx < customFiltered.count - 1 { rowDivider }
                }
            }
            .cardStyle(padding: 0)
        }

        ForEach(orderedGroups, id: \.self) { g in
            sectionHeader(g.rawValue)
            let items = grouped[g] ?? []
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.code) { idx, ex in
                    NavigationLink(value: ex) {
                        builtinRow(ex)
                    }
                    .buttonStyle(.plain)
                    if idx < items.count - 1 { rowDivider }
                }
            }
            .cardStyle(padding: 0)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title).eyebrowStyle().padding(.top, 4)
    }

    private var rowDivider: some View {
        Rectangle().fill(Theme.Color.border).frame(height: 1)
            .padding(.leading, 56)
    }

    private func builtinRow(_ ex: BuiltinExercise) -> some View {
        let pr = PRStats.latestPR(for: ex.code, in: workouts)
        return HStack(spacing: Theme.Spacing.md) {
            thumb(initial: String(ex.name.prefix(1)))
            VStack(alignment: .leading, spacing: 2) {
                Text(ex.name)
                    .font(Theme.Font.body(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                Text(humanize(code: ex.code))
                    .font(Theme.Font.mono(size: 11))
                    .foregroundStyle(Theme.Color.muted)
            }
            Spacer()
            if let pr {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("PR").eyebrowStyle()
                    Text("\(formatKg(pr.weightKg))kg")
                        .numStyle(size: 13)
                        .foregroundStyle(Theme.Color.fg)
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Color.muted)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(minHeight: 60)
    }

    private func customRow(_ ex: CustomExercise) -> some View {
        let key = ex.localId.uuidString
        let pr = PRStats.latestPR(for: key, in: workouts)
        return HStack(spacing: Theme.Spacing.md) {
            thumb(initial: String(ex.name.prefix(1)), tint: Theme.Color.accentMagenta.opacity(0.25))
            VStack(alignment: .leading, spacing: 2) {
                Text(ex.name)
                    .font(Theme.Font.body(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                Text("自定义 · \(ex.primaryMuscle ?? "—")")
                    .font(Theme.Font.mono(size: 11))
                    .foregroundStyle(Theme.Color.muted)
            }
            Spacer()
            if let pr {
                Text("\(formatKg(pr.weightKg))kg")
                    .numStyle(size: 13)
                    .foregroundStyle(Theme.Color.fg2)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(minHeight: 60)
    }

    private func thumb(initial: String, tint: Color = Theme.Color.surface2) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint)
                .frame(width: 42, height: 42)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Color.border, lineWidth: 1))
            Text(initial)
                .font(Theme.Font.body(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
        }
    }

    /// "BB_BENCH_PRESS" -> "Bb Bench Press"
    private func humanize(code: String) -> String {
        code.split(separator: "_").map { $0.lowercased().capitalized }.joined(separator: " ")
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
            // 必要的 Form 用法：自定义动作创建 sheet，原生 Picker/TextField 体验最稳。
            Form {
                TextField("动作名称", text: $name)
                Picker("主要肌群", selection: $muscle) {
                    ForEach(MuscleGroup.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("器械", selection: $equipment) {
                    ForEach(EquipmentType.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Color.bg)
            .navigationTitle("新建动作")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .tint(Theme.Color.accentCyan)
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

/// 必要的 List 用法：`.searchable` 与 `List` 搭配是 SwiftUI 原生路径，
/// 自绘 ScrollView 仍需手写 query 绑定与键盘联动，picker 是 sheet 模态，故保留 List。
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
                                PickerExerciseRow(name: ex.name, muscle: ex.primaryMuscle, equipment: ex.equipmentType, isCustom: true)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Section("标准库") {
                    ForEach(result.builtin) { ex in
                        Button { pick(builtin: ex) } label: {
                            PickerExerciseRow(name: ex.name, muscle: ex.primaryMuscle, equipment: ex.equipmentType, isCustom: false)
                        }.buttonStyle(.plain)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Color.bg)
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

private struct PickerExerciseRow: View {
    let name: String
    let muscle: String?
    let equipment: String?
    let isCustom: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).foregroundStyle(Theme.Color.fg)
                if let detail = [muscle, equipment].compactMap({ $0 }).joined(separator: " · ").nilIfEmpty {
                    Text(detail).font(.caption).foregroundStyle(Theme.Color.muted)
                }
            }
            Spacer()
            if isCustom {
                Text("个人")
                    .font(Theme.Font.mono(size: 10, weight: .semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Theme.Color.accentCyan.opacity(0.18), in: Capsule())
                    .foregroundStyle(Theme.Color.accentCyan)
            }
        }
        .listRowBackground(Theme.Color.bg)
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
    /// 加入今日训练后导航进入的会话。
    @State private var startedSession: Workout?

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Color.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    cover
                    title
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
        .navigationDestination(item: $startedSession) { WorkoutLoggingView(workout: $0) }
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

    /// 加入今日训练：经单一活跃会话守卫——存在进行中会话则追加动作（即「继续」），
    /// 否则新建唯一会话。随后导航进入 Live 记录界面。
    private func addToTodayWorkout() {
        let target = WorkoutSession.activeSession(in: modelContext) ?? {
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
        startedSession = target
    }
}
