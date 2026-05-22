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
                    ExerciseRow(name: ex.name, muscle: ex.primaryMuscle, equipment: ex.equipmentType, isCustom: false)
                }
            }
        }
        .searchable(text: $query, prompt: "搜索动作")
        .navigationTitle("动作库")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { muscleFilter }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingCreate) { CustomExerciseEditorView() }
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
