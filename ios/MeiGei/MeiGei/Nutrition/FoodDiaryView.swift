import SwiftUI
import SwiftData

/// 饮食 tab 根视图：当日营养进度 + 按餐次日记 + 复制昨天 + 引导门。
struct FoodDiaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [FoodEntry]
    @Query private var goals: [NutritionGoal]

    @State private var selectedDay: Date = Calendar.current.startOfDay(for: .now)
    @State private var pickerMeal: MealType?
    @State private var showingGoalEditor = false
    @State private var showingOnboarding = false

    private var goal: NutritionGoal? { goals.first }

    private var dayEntries: [FoodEntry] {
        entries.filter { Calendar.current.isDate($0.dayStart, inSameDayAs: selectedDay) }
    }

    private var dayTotals: NutritionTotals {
        dayEntries.reduce(NutritionTotals()) { $0 + $1.totals }
    }

    var body: some View {
        List {
            daySwitcher
            if let goal {
                TargetProgressSection(totals: dayTotals, targets: goal.targets) {
                    showingGoalEditor = true
                }
            } else {
                Section {
                    Button("设置每日营养目标") { showingOnboarding = true }
                }
            }
            ForEach(MealType.allCases) { meal in
                mealSection(meal)
            }
        }
        .navigationTitle("饮食")
        .sheet(item: $pickerMeal) { meal in
            FoodSearchView { pick, grams in
                addEntry(pick: pick, grams: grams, meal: meal)
            }
        }
        .sheet(isPresented: $showingGoalEditor) {
            if let goal { NutritionGoalEditorView(goal: goal) }
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            NutritionOnboardingView { saveOnboarding($0) }
        }
        .onAppear {
            if goal == nil { showingOnboarding = true }
        }
    }

    private var daySwitcher: some View {
        HStack {
            Button { shiftDay(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(dayTitle).font(.headline)
            Spacer()
            Button { shiftDay(1) } label: { Image(systemName: "chevron.right") }
                .disabled(Calendar.current.isDateInToday(selectedDay))
        }
        .buttonStyle(.borderless)
    }

    private var dayTitle: String {
        if Calendar.current.isDateInToday(selectedDay) { return "今天" }
        if Calendar.current.isDateInYesterday(selectedDay) { return "昨天" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: selectedDay)
    }

    private func mealSection(_ meal: MealType) -> some View {
        let items = dayEntries.filter { $0.meal == meal }.sorted { $0.createdAt < $1.createdAt }
        let mealKcal = items.reduce(0) { $0 + $1.totals.kcal }
        return Section {
            ForEach(items) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.foodName)
                        Text("\(fmtNum(entry.grams))g · \(fmtNum(entry.totals.kcal)) kcal")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if entry.source == "personal" {
                        Text("个人").font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.tint.opacity(0.15)).clipShape(Capsule())
                    }
                }
            }
            .onDelete { offsets in deleteEntries(items, at: offsets) }
            Button { pickerMeal = meal } label: {
                Label("添加食物", systemImage: "plus")
            }
            if !hasEntries(meal: meal, day: selectedDay), hasEntries(meal: meal, day: yesterday) {
                Button { copyYesterday(meal: meal) } label: {
                    Label("复制昨天", systemImage: "doc.on.doc")
                }
            }
        } header: {
            HStack {
                Label(meal.rawValue, systemImage: meal.systemImage)
                Spacer()
                if mealKcal > 0 { Text("\(fmtNum(mealKcal)) kcal").foregroundStyle(.secondary) }
            }
        }
    }

    // MARK: - 数据操作

    private var yesterday: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: selectedDay)!
    }

    private func hasEntries(meal: MealType, day: Date) -> Bool {
        entries.contains { $0.meal == meal && Calendar.current.isDate($0.dayStart, inSameDayAs: day) }
    }

    private func shiftDay(_ delta: Int) {
        guard let d = Calendar.current.date(byAdding: .day, value: delta, to: selectedDay) else { return }
        selectedDay = Calendar.current.startOfDay(for: d)
    }

    private func addEntry(pick: FoodPick, grams: Double, meal: MealType) {
        let entry = FoodEntry(dayStart: selectedDay, meal: meal, foodName: pick.name,
                              source: pick.source, grams: grams,
                              kcalPer100: pick.kcalPer100, proteinPer100: pick.proteinPer100,
                              carbPer100: pick.carbPer100, fatPer100: pick.fatPer100,
                              fiberPer100: pick.fiberPer100, sugarPer100: pick.sugarPer100,
                              sodiumPer100: pick.sodiumPer100)
        modelContext.insert(entry)
        try? modelContext.save()
    }

    private func saveOnboarding(_ goal: NutritionGoal) {
        modelContext.insert(goal)
        try? modelContext.save()
    }

    private func copyYesterday(meal: MealType) {
        let src = entries.filter {
            $0.meal == meal && Calendar.current.isDate($0.dayStart, inSameDayAs: yesterday)
        }
        for e in src {
            let copy = FoodEntry(dayStart: selectedDay, meal: meal, foodName: e.foodName,
                                 source: e.source, grams: e.grams,
                                 kcalPer100: e.kcalPer100, proteinPer100: e.proteinPer100,
                                 carbPer100: e.carbPer100, fatPer100: e.fatPer100,
                                 fiberPer100: e.fiberPer100, sugarPer100: e.sugarPer100,
                                 sodiumPer100: e.sodiumPer100)
            modelContext.insert(copy)
        }
        try? modelContext.save()
    }

    private func deleteEntries(_ items: [FoodEntry], at offsets: IndexSet) {
        for i in offsets { modelContext.delete(items[i]) }
        try? modelContext.save()
    }
}
