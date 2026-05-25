import SwiftUI
import SwiftData

// MARK: - 计划模板列表

struct PlanListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<WorkoutPlan> { $0.deletedAt == nil },
           sort: \WorkoutPlan.updatedAt, order: .reverse)
    private var plans: [WorkoutPlan]
    @State private var editing: WorkoutPlan?
    @State private var creatingNew = false

    var body: some View {
        List {
            ForEach(plans) { plan in
                NavigationLink(value: plan) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.name).foregroundStyle(Theme.Color.fg)
                        Text("\(plan.items.count) 个动作").font(.caption).foregroundStyle(Theme.Color.fg2)
                    }
                }
                .listRowBackground(Theme.Color.surface)
            }
            .onDelete(perform: delete)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Color.bg)
        .navigationTitle("训练计划")
        .overlay { if plans.isEmpty { ContentUnavailableView("还没有计划", systemImage: "list.bullet.rectangle", description: Text("点右上角 + 新建一个训练计划模板")) } }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creatingNew = true } label: { Image(systemName: "plus") }
            }
        }
        .navigationDestination(for: WorkoutPlan.self) { PlanEditorView(plan: $0) }
        .navigationDestination(isPresented: $creatingNew) { PlanEditorView(plan: nil) }
    }

    private func delete(_ offsets: IndexSet) {
        for i in offsets { plans[i].markDeleted() }
        try? modelContext.save()
    }
}

// MARK: - 3.5 计划编辑（动作项带稳定 itemId）

struct PlanEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let existing: WorkoutPlan?
    @State private var name: String
    @State private var items: [PlanItem]
    @State private var pickingExercise = false
    @State private var editingItem: PlanItem?

    init(plan: WorkoutPlan?) {
        self.existing = plan
        _name = State(initialValue: plan?.name ?? "")
        _items = State(initialValue: plan?.items.sorted { $0.orderIndex < $1.orderIndex } ?? [])
    }

    var body: some View {
        Form {
            Section { TextField("计划名称", text: $name) }
            Section("动作") {
                ForEach(items) { item in
                    Button { editingItem = item } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.exerciseName).foregroundStyle(.primary)
                                Text(subtitle(item)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }
                .onMove(perform: move)
                .onDelete(perform: deleteItems)
                Button { pickingExercise = true } label: { Label("添加动作", systemImage: "plus") }
            }
        }
        .navigationTitle(existing == nil ? "新建计划" : "编辑计划")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .sheet(isPresented: $pickingExercise) {
            ExercisePickerView { pick in addItem(pick) }
        }
        .sheet(item: $editingItem) { item in
            PlanItemEditorView(item: item) { updated in
                if let idx = items.firstIndex(where: { $0.itemId == updated.itemId }) { items[idx] = updated }
            }
        }
    }

    private func subtitle(_ item: PlanItem) -> String {
        var parts: [String] = []
        if let s = item.suggestedSets, let r = item.suggestedReps { parts.append("\(s)组 × \(r)次") }
        else if let s = item.suggestedSets { parts.append("\(s)组") }
        if let w = item.suggestedWeightKg { parts.append("\(formatKg(w)) kg") }
        return parts.isEmpty ? "未设建议" : parts.joined(separator: " · ")
    }

    private func addItem(_ pick: ExercisePick) {
        items.append(PlanItem(builtinExerciseCode: pick.builtinCode, customExerciseId: pick.customId,
                              exerciseName: pick.name, orderIndex: items.count))
    }
    private func move(_ offsets: IndexSet, _ to: Int) {
        items.move(fromOffsets: offsets, toOffset: to)
        reindex()
    }
    private func deleteItems(_ offsets: IndexSet) { items.remove(atOffsets: offsets); reindex() }
    private func reindex() { for i in items.indices { items[i].orderIndex = i } }

    private func save() {
        reindex()
        let plan: WorkoutPlan
        if let existing {
            plan = existing
            plan.name = name.trimmingCharacters(in: .whitespaces)
            plan.items = items
            plan.markDirty()
        } else {
            plan = WorkoutPlan(name: name.trimmingCharacters(in: .whitespaces), items: items)
            modelContext.insert(plan)
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - 单个动作项的建议参数编辑

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
                }
            }
        }
    }
}

/// 去掉多余小数（80.0 → "80"，72.5 → "72.5"）。
func formatKg(_ value: Double) -> String {
    value == value.rounded() ? String(Int(value)) : String(value)
}
