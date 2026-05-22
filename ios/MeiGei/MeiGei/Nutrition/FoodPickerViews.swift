import SwiftUI
import SwiftData

/// 食材搜索选择器（4.2 离线搜索 + 4.5 选食材入口）。
/// 标准库优先展示并带来源标识；搜不到时可新建个人食材。
struct FoodSearchView: View {
    @Query(sort: \CustomFood.updatedAt, order: .reverse) private var custom: [CustomFood]
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var category: FoodCategory?
    @State private var picked: FoodPick?
    @State private var showingCreate = false

    /// 选定食材与克数后回调（grams 为实际食用克数）。
    let onSave: (FoodPick, Double) -> Void

    var body: some View {
        NavigationStack {
            let result = filterFoods(builtin: BuiltinFood.standard, custom: custom,
                                     query: query, category: category)
            List {
                Section("标准库") {
                    ForEach(result.builtin) { f in
                        Button { picked = FoodPick(builtin: f) } label: {
                            FoodRow(name: f.name, detail: "\(f.category) · \(fmtNum(f.kcal)) kcal/100g", isPersonal: false)
                        }.buttonStyle(.plain)
                    }
                    if result.builtin.isEmpty {
                        Text("标准库无匹配结果").foregroundStyle(.secondary)
                    }
                }
                if !result.custom.isEmpty {
                    Section("个人") {
                        ForEach(result.custom) { f in
                            Button { picked = FoodPick(custom: f) } label: {
                                FoodRow(name: f.name, detail: "\(fmtNum(f.kcal ?? 0)) kcal/100g", isPersonal: true)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Section {
                    Button { showingCreate = true } label: {
                        Label("找不到？新建个人食材", systemImage: "plus")
                    }
                }
            }
            .searchable(text: $query, prompt: "搜索食材")
            .navigationTitle("选择食材")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { categoryFilter }
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .navigationDestination(item: $picked) { pick in
                AddFoodEntryView(pick: pick) { grams in
                    onSave(pick, grams)
                    dismiss()
                }
            }
            .sheet(isPresented: $showingCreate) { CustomFoodEditorView() }
        }
    }

    private var categoryFilter: some View {
        Menu {
            Button("全部分类") { category = nil }
            ForEach(FoodCategory.allCases) { c in Button(c.rawValue) { category = c } }
        } label: {
            Label(category?.rawValue ?? "分类", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
}

private struct FoodRow: View {
    let name: String
    let detail: String
    let isPersonal: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if isPersonal {
                Text("个人").font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.tint.opacity(0.15)).clipShape(Capsule())
            }
        }
    }
}

/// 分量录入（4.5）：输入克数，实时换算 7 项营养。
struct AddFoodEntryView: View {
    let pick: FoodPick
    let onConfirm: (Double) -> Void
    @State private var gramsText = "100"

    private var grams: Double { Double(gramsText) ?? 0 }
    private var totals: NutritionTotals {
        let f = grams / 100
        return NutritionTotals(kcal: pick.kcalPer100 * f, proteinG: pick.proteinPer100 * f,
                               carbG: pick.carbPer100 * f, fatG: pick.fatPer100 * f,
                               fiberG: pick.fiberPer100 * f, sugarG: pick.sugarPer100 * f,
                               sodiumMg: pick.sodiumPer100 * f)
    }

    var body: some View {
        Form {
            Section("分量") {
                HStack {
                    TextField("克数", text: $gramsText).keyboardType(.decimalPad)
                    Text("g").foregroundStyle(.secondary)
                }
            }
            Section("换算后营养") {
                LabeledContent("热量", value: "\(fmtNum(totals.kcal)) kcal")
                LabeledContent("蛋白质", value: "\(fmtNum(totals.proteinG)) g")
                LabeledContent("碳水", value: "\(fmtNum(totals.carbG)) g")
                LabeledContent("脂肪", value: "\(fmtNum(totals.fatG)) g")
                LabeledContent("纤维", value: "\(fmtNum(totals.fiberG)) g")
                LabeledContent("糖", value: "\(fmtNum(totals.sugarG)) g")
                LabeledContent("钠", value: "\(fmtNum(totals.sodiumMg)) mg")
            }
        }
        .navigationTitle(pick.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("记录") { onConfirm(grams) }.disabled(grams <= 0)
            }
        }
    }
}

/// 自定义食材创建（4.4）：填名称 + 每 100g 的 7 项营养，标记为个人来源、参与同步。
struct CustomFoodEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carb = ""
    @State private var fat = ""
    @State private var fiber = ""
    @State private var sugar = ""
    @State private var sodium = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("名称") {
                    TextField("如：红烧排骨", text: $name)
                }
                Section("每 100g 营养") {
                    nutrientField("热量 (kcal)", $kcal)
                    nutrientField("蛋白质 (g)", $protein)
                    nutrientField("碳水 (g)", $carb)
                    nutrientField("脂肪 (g)", $fat)
                    nutrientField("纤维 (g)", $fiber)
                    nutrientField("糖 (g)", $sugar)
                    nutrientField("钠 (mg)", $sodium)
                }
            }
            .navigationTitle("新建个人食材")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func nutrientField(_ label: String, _ text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
        }
    }

    private func save() {
        let food = CustomFood(name: name.trimmingCharacters(in: .whitespaces),
                              source: "personal", unitBasis: "100g",
                              kcal: Double(kcal), proteinG: Double(protein), carbG: Double(carb),
                              fatG: Double(fat), fiberG: Double(fiber), sugarG: Double(sugar),
                              sodiumMg: Double(sodium))
        modelContext.insert(food)
        try? modelContext.save()
        dismiss()
    }
}
