import SwiftUI
import SwiftData

// MARK: - 食材选择器（Screen 08，Neon 改版）

/// chip 项：最近 / 收藏 / 蛋白质 / 主食 / 蔬菜 / 水果 / 自定义。
private struct FoodChip: Identifiable, Hashable {
    let id: String
    let title: String
    /// nil 表示走「最近/收藏/自定义」特殊筛选；非 nil 时按食材分类筛标准库。
    let category: FoodCategory?
    /// 「最近 / 收藏 / 自定义」三个语义入口。
    let special: Special?
    enum Special: String { case recent, favorite, custom }
}

/// 入口：sheet 弹出。navbar 标题「添加 · {餐次}」+ 右上「取消」。
struct FoodSearchView: View {
    @Query(sort: \CustomFood.updatedAt, order: .reverse) private var custom: [CustomFood]
    @Query(sort: \FoodEntry.createdAt, order: .reverse) private var allEntries: [FoodEntry]
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var chipId: String = "recent"
    @State private var picked: FoodPick?
    @State private var addedKeys: Set<String> = []
    @State private var showingCreate = false

    /// FoodDiaryView 弹出时传入的餐次（决定 navbar 副标 + addEntry 归属）。
    /// 兼容现有调用方未传值的场景：默认 .snack。
    let meal: MealType
    let onSave: (FoodPick, Double) -> Void

    init(meal: MealType = .snack, onSave: @escaping (FoodPick, Double) -> Void) {
        self.meal = meal
        self.onSave = onSave
    }

    private let chips: [FoodChip] = [
        .init(id: "recent",    title: "最近",   category: nil, special: .recent),
        .init(id: "favorite",  title: "收藏",   category: nil, special: .favorite),
        .init(id: "protein",   title: "蛋白质", category: .meat, special: nil),
        .init(id: "staple",    title: "主食",   category: .staple, special: nil),
        .init(id: "vegetable", title: "蔬菜",   category: .vegetable, special: nil),
        .init(id: "fruit",     title: "水果",   category: .fruit, special: nil),
        .init(id: "custom",    title: "自定义", category: nil, special: .custom),
    ]

    private var selectedChip: FoodChip? {
        chips.first(where: { $0.id == chipId })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Color.bg.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        searchBar
                        HorizontalChipPicker(items: chips, selection: $chipId) { $0.title }
                            .padding(.horizontal, -Theme.Spacing.lg)

                        listSection
                        addCustomCTA
                        Color.clear.frame(height: 32)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
                }
            }
            .navigationTitle("添加 · \(meal.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.tint(Theme.Color.fg2)
                }
            }
            .navigationDestination(item: $picked) { pick in
                AddFoodEntryView(pick: pick) { grams in
                    onSave(pick, grams)
                    addedKeys.insert(pick.id)
                    picked = nil
                }
            }
            .sheet(isPresented: $showingCreate) { CustomFoodEditorView() }
        }
        .preferredColorScheme(.dark)
    }

    private var searchBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.Color.muted)
            TextField("", text: $query, prompt: Text("搜索 1500 项标准食材").foregroundColor(Theme.Color.muted))
                .font(Theme.Font.body(size: 14))
                .foregroundStyle(Theme.Color.fg)
                .disabled(true) // noop，本 change 不实现真实搜索
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: 40)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.Color.border, lineWidth: 1))
    }

    @ViewBuilder
    private var listSection: some View {
        switch selectedChip?.special {
        case .recent:
            recentSection
        case .favorite:
            // 备注：CustomFood 模型当前无 isFavorite 字段（proposal Non-goals 禁止改 schema）；
            // 暂以「全部自定义食材」充当收藏入口，待后续 change 加 isFavorite。
            customSection(label: "收藏")
        case .custom:
            customSection(label: "自定义")
        case .none:
            categorySection
        }
    }

    private var recentSection: some View {
        let recentPicks = uniqueRecentPicks(limit: 20)
        return Group {
            if recentPicks.isEmpty {
                emptyHint("还没有记录 · 选个分类开始添加")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentPicks.enumerated()), id: \.element.id) { idx, pick in
                        pickRow(pick: pick, detail: pickDetail(pick))
                        if idx < recentPicks.count - 1 { rowDivider }
                    }
                }
                .cardStyle(padding: 0)
            }
        }
    }

    private func customSection(label: String) -> some View {
        let actives = custom.filter { $0.deletedAt == nil }
        return Group {
            if actives.isEmpty {
                emptyHint("还没有自定义食材，点下方「+ 新建食材」")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(actives.enumerated()), id: \.element.localId) { idx, f in
                        let p = FoodPick(custom: f)
                        pickRow(pick: p, detail: "\(fmtNum(f.kcal ?? 0)) kcal/100g · 自定义")
                        if idx < actives.count - 1 { rowDivider }
                    }
                }
                .cardStyle(padding: 0)
            }
        }
    }

    private var categorySection: some View {
        let cat = selectedChip?.category
        let result = filterFoods(builtin: BuiltinFood.standard, custom: [], query: query, category: cat)
        return Group {
            if result.builtin.isEmpty {
                emptyHint("该分类暂无标准库样本")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(result.builtin.enumerated()), id: \.element.code) { idx, f in
                        let p = FoodPick(builtin: f)
                        pickRow(pick: p, detail: "\(f.category) · \(fmtNum(f.kcal)) kcal/100g")
                        if idx < result.builtin.count - 1 { rowDivider }
                    }
                }
                .cardStyle(padding: 0)
            }
        }
    }

    private var rowDivider: some View {
        Rectangle().fill(Theme.Color.border).frame(height: 1).padding(.leading, 60)
    }

    private func emptyHint(_ msg: String) -> some View {
        Text(msg)
            .font(Theme.Font.body(size: 13))
            .foregroundStyle(Theme.Color.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
    }

    private var addCustomCTA: some View {
        Button { showingCreate = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                Text("新建个人食材")
            }
            .font(Theme.Font.body(size: 14, weight: .semibold))
            .foregroundStyle(Theme.Color.accentCyan)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .strokeBorder(Theme.Color.border, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            )
        }
        .buttonStyle(.plain)
    }

    private func pickRow(pick: FoodPick, detail: String) -> some View {
        let added = addedKeys.contains(pick.id)
        return Button {
            picked = pick
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                thumb(initial: String(pick.name.prefix(1)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(pick.name)
                        .font(Theme.Font.body(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Color.fg)
                    Text(detail)
                        .font(Theme.Font.mono(size: 11))
                        .foregroundStyle(Theme.Color.muted)
                }
                Spacer()
                statusButton(added: added)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .frame(minHeight: 60)
        }
        .buttonStyle(.plain)
    }

    private func thumb(initial: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.Color.surface2)
                .frame(width: 42, height: 42)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Color.border, lineWidth: 1))
            Text(initial)
                .font(Theme.Font.body(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
        }
    }

    private func statusButton(added: Bool) -> some View {
        ZStack {
            Circle()
                .fill(added ? Theme.Color.accentCyan : Theme.Color.surface)
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(added ? Color.clear : Theme.Color.border, lineWidth: 1))
            Image(systemName: added ? "checkmark" : "plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(added ? Theme.Color.bg : Theme.Color.fg2)
        }
    }

    // MARK: - 最近食材抽取

    /// 按 FoodEntry.createdAt desc 取前 limit 项；按 (name, source) 去重保留最新。
    private func uniqueRecentPicks(limit: Int) -> [FoodPick] {
        var seen = Set<String>()
        var out: [FoodPick] = []
        for e in allEntries {
            let key = e.source + ":" + e.foodName
            if seen.contains(key) { continue }
            seen.insert(key)
            out.append(FoodPick(
                name: e.foodName,
                source: e.source,
                kcalPer100: e.kcalPer100,
                proteinPer100: e.proteinPer100,
                carbPer100: e.carbPer100,
                fatPer100: e.fatPer100,
                fiberPer100: e.fiberPer100,
                sugarPer100: e.sugarPer100,
                sodiumPer100: e.sodiumPer100
            ))
            if out.count >= limit { break }
        }
        return out
    }

    private func pickDetail(_ pick: FoodPick) -> String {
        let src = pick.source == "personal" ? "自定义" : "标准库"
        return "\(src) · \(fmtNum(pick.kcalPer100)) kcal/100g"
    }
}

// MARK: - 分量录入

/// 分量录入：克数 + 实时换算 7 项营养。沿用 Form（sheet 表单合理用法）。
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
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text("AMOUNT · 分量").eyebrowStyle()
                    HStack {
                        TextField("克数", text: $gramsText)
                            .keyboardType(.decimalPad)
                            .font(Theme.Font.display(size: 28, weight: .bold))
                            .foregroundStyle(Theme.Color.fg)
                        Text("g")
                            .font(Theme.Font.mono(size: 16))
                            .foregroundStyle(Theme.Color.fg2)
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.Color.border, lineWidth: 1))

                    Text("NUTRITION · 实际营养").eyebrowStyle()
                    VStack(spacing: 0) {
                        nutritionRow("热量",   "\(fmtNum(totals.kcal)) kcal")
                        rowDivider
                        nutritionRow("蛋白质", "\(fmtNum(totals.proteinG)) g")
                        rowDivider
                        nutritionRow("碳水",   "\(fmtNum(totals.carbG)) g")
                        rowDivider
                        nutritionRow("脂肪",   "\(fmtNum(totals.fatG)) g")
                        rowDivider
                        nutritionRow("纤维",   "\(fmtNum(totals.fiberG)) g")
                        rowDivider
                        nutritionRow("糖",     "\(fmtNum(totals.sugarG)) g")
                        rowDivider
                        nutritionRow("钠",     "\(fmtNum(totals.sodiumMg)) mg")
                    }
                    .cardStyle(padding: 0)

                    Button { onConfirm(grams) } label: {
                        Text("记录")
                            .font(Theme.Font.body(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.Color.bg)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Theme.Color.accentCyan, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                    }
                    .buttonStyle(.plain)
                    .disabled(grams <= 0)
                    .opacity(grams <= 0 ? 0.4 : 1)
                    .neonGlow(.cyan, intensity: .sm, cornerRadius: Theme.Radius.md)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }
        }
        .navigationTitle(pick.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var rowDivider: some View {
        Rectangle().fill(Theme.Color.border).frame(height: 1).padding(.horizontal, Theme.Spacing.md)
    }

    private func nutritionRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(Theme.Font.body(size: 14)).foregroundStyle(Theme.Color.fg2)
            Spacer()
            Text(value).font(Theme.Font.mono(size: 13)).foregroundStyle(Theme.Color.fg)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: 42)
    }
}

// MARK: - FoodPick memberwise init（供「最近」直接构造）

extension FoodPick {
    init(name: String, source: String, kcalPer100: Double, proteinPer100: Double,
         carbPer100: Double, fatPer100: Double, fiberPer100: Double,
         sugarPer100: Double, sodiumPer100: Double) {
        self.name = name
        self.source = source
        self.kcalPer100 = kcalPer100
        self.proteinPer100 = proteinPer100
        self.carbPer100 = carbPer100
        self.fatPer100 = fatPer100
        self.fiberPer100 = fiberPer100
        self.sugarPer100 = sugarPer100
        self.sodiumPer100 = sodiumPer100
    }
}

// MARK: - 自定义食材编辑（保留 Form，sheet 表单合理用法）

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
            // 必要的 Form 用法：营养字段是密集数字编辑表单，sheet 隔离不影响主屏背景。
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
            .scrollContentBackground(.hidden)
            .background(Theme.Color.bg)
            .navigationTitle("新建个人食材")
            .navigationBarTitleDisplayMode(.inline)
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
