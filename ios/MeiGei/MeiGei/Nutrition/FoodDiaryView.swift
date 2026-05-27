import SwiftUI
import SwiftData

/// 饮食 tab（Screen 07，Neon 改版）：日期切换 + MacroRingView + 餐次分块 + FAB。
struct FoodDiaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [FoodEntry]
    @Query private var goals: [NutritionGoal]

    @State private var selectedDay: Date = Calendar.current.startOfDay(for: .now)
    @State private var pickerMeal: MealType?
    @State private var showingGoalEditor = false
    @State private var showingOnboarding = false
    @State private var showingDayPicker = false
    @State private var expandedMeals: Set<String> = []

    private var goal: NutritionGoal? { goals.first }

    private var dayEntries: [FoodEntry] {
        entries.filter { Calendar.current.isDate($0.dayStart, inSameDayAs: selectedDay) }
    }

    private var dayTotals: NutritionTotals {
        dayEntries.reduce(NutritionTotals()) { $0 + $1.totals }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Theme.Color.bg.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text(dayEyebrow).eyebrowStyle()

                    if let goal {
                        MacroRingView(
                            totals: dayTotals,
                            targets: goal.targets,
                            waterMl: 0,
                            targetWaterMl: 2000
                        )
                    } else {
                        onboardingCard
                    }

                    ForEach(MealType.allCases) { meal in
                        let items = dayEntries
                            .filter { $0.meal == meal }
                            .sorted { $0.createdAt < $1.createdAt }
                        if !items.isEmpty {
                            MealBlockView(
                                meal: meal,
                                items: items,
                                expanded: expandedMeals.contains(meal.rawValue),
                                onToggleExpand: { toggleExpand(meal) },
                                onAdd: { pickerMeal = meal }
                            )
                        }
                    }

                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }
            fab
        }
        .navigationTitle("饮食")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: Theme.Spacing.md) {
                    Button { showingDayPicker = true } label: {
                        Image(systemName: "calendar").foregroundStyle(Theme.Color.fg)
                    }
                    Button { pickerMeal = defaultMealForNow() } label: {
                        Image(systemName: "plus").foregroundStyle(Theme.Color.fg)
                    }
                }
            }
        }
        .sheet(item: $pickerMeal) { meal in
            FoodSearchView(meal: meal) { pick, grams in
                addEntry(pick: pick, grams: grams, meal: meal)
            }
        }
        .sheet(isPresented: $showingGoalEditor) {
            if let goal { NutritionGoalEditorView(goal: goal) }
        }
        .sheet(isPresented: $showingDayPicker) {
            dayPickerSheet
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            NutritionOnboardingView { saveOnboarding($0) }
        }
        .onAppear {
            if goal == nil { showingOnboarding = true }
        }
    }

    private var dayEyebrow: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy 年 M 月 d 日 · EEEE"
        let base = f.string(from: selectedDay)
        if Calendar.current.isDateInToday(selectedDay) { return "今天 · " + base }
        if Calendar.current.isDateInYesterday(selectedDay) { return "昨天 · " + base }
        return base
    }

    private var onboardingCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("SETUP · 营养目标").eyebrowStyle()
            Text("先设定每日热量与三大宏量")
                .font(Theme.Font.body(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
            Button { showingOnboarding = true } label: {
                Text("开始引导")
                    .font(Theme.Font.body(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Color.bg)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .frame(height: 38)
                    .background(Theme.Color.accentCyan, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
            .buttonStyle(.plain)
            .neonGlow(.cyan, intensity: .sm, cornerRadius: Theme.Radius.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var fab: some View {
        Button { pickerMeal = defaultMealForNow() } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.Color.bg)
                .frame(width: 56, height: 56)
                .background(Theme.Color.accentCyan, in: Circle())
        }
        .buttonStyle(.plain)
        .neonGlow(.cyan, intensity: .medium, cornerRadius: 28)
        .padding(.trailing, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.lg)
    }

    private var dayPickerSheet: some View {
        NavigationStack {
            VStack {
                DatePicker("选择日期", selection: $selectedDay, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                Spacer()
            }
            .background(Theme.Color.bg)
            .preferredColorScheme(.dark)
            .navigationTitle("选择日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showingDayPicker = false }.tint(Theme.Color.accentCyan)
                }
            }
        }
    }

    // MARK: - 行为

    private func toggleExpand(_ meal: MealType) {
        if expandedMeals.contains(meal.rawValue) {
            expandedMeals.remove(meal.rawValue)
        } else {
            expandedMeals.insert(meal.rawValue)
        }
    }

    /// 按当前时间映射到默认餐次：< 10 早 / < 14 午 / < 18 加餐 / 否则 晚。
    private func defaultMealForNow() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case ..<10:  return .breakfast
        case ..<14:  return .lunch
        case ..<18:  return .snack
        default:     return .dinner
        }
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
}

// MARK: - 餐次分块

/// 餐次分块：粗体餐次名 + mono kcal·HH:mm 副标；4 条以上折叠为「+ N 项 / 合计」灰行。
struct MealBlockView: View {
    let meal: MealType
    let items: [FoodEntry]
    let expanded: Bool
    let onToggleExpand: () -> Void
    let onAdd: () -> Void

    private var mealKcal: Double { items.reduce(0) { $0 + $1.totals.kcal } }

    private var firstTime: String {
        guard let earliest = items.map(\.createdAt).min() else { return "—" }
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: earliest)
    }

    private var visibleItems: [FoodEntry] {
        if items.count <= 4 || expanded { return items }
        return Array(items.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                Text(meal.rawValue)
                    .font(Theme.Font.body(size: 15, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                Spacer()
                Text("\(Int(mealKcal.rounded())) kcal · \(firstTime)")
                    .font(Theme.Font.mono(size: 11))
                    .foregroundStyle(Theme.Color.muted)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)

            Rectangle().fill(Theme.Color.border).frame(height: 1)

            ForEach(Array(visibleItems.enumerated()), id: \.element.localId) { idx, entry in
                row(entry)
                if idx < visibleItems.count - 1 {
                    Rectangle().fill(Theme.Color.border).frame(height: 1)
                }
            }

            if items.count > 4 && !expanded {
                Rectangle().fill(Theme.Color.border).frame(height: 1)
                Button(action: onToggleExpand) {
                    HStack {
                        Text("+ \(items.count - 4) 项")
                            .font(Theme.Font.mono(size: 12))
                            .foregroundStyle(Theme.Color.muted)
                        Spacer()
                        Text("合计 \(Int(mealKcal.rounded())) kcal")
                            .font(Theme.Font.mono(size: 12))
                            .foregroundStyle(Theme.Color.muted)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.Color.border, lineWidth: 1))
    }

    private func row(_ entry: FoodEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.foodName)
                    .font(Theme.Font.body(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                Text("\(Int(entry.grams)) g")
                    .font(Theme.Font.mono(size: 11))
                    .foregroundStyle(Theme.Color.muted)
            }
            Spacer()
            Text("\(Int(entry.totals.kcal.rounded())) kcal")
                .font(Theme.Font.mono(size: 12))
                .foregroundStyle(Theme.Color.fg2)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }
}
