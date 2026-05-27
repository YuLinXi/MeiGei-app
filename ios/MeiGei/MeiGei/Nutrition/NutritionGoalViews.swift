import SwiftUI
import SwiftData

/// 首次引导（4.7）：填写资料 → Mifflin-St Jeor 计算每日热量与三大宏量。
struct NutritionOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    let onComplete: (NutritionGoal) -> Void

    @State private var sex: BioSex = .male
    @State private var age = 25
    @State private var heightCm = 170.0
    @State private var weightKg = 65.0
    @State private var activity: ActivityLevel = .light
    @State private var goal: FitnessGoal = .maintain

    private var preview: DailyTargets {
        NutritionMath.recommend(sex: sex, weightKg: weightKg, heightCm: heightCm,
                                age: age, activity: activity, goal: goal)
    }

    var body: some View {
        NavigationStack {
            // 必要的 Form 用法：onboarding 全屏密集字段录入，sheet 隔离视觉影响。
            Form {
                Section("基本资料") {
                    Picker("性别", selection: $sex) {
                        ForEach(BioSex.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Stepper("年龄 \(age)", value: $age, in: 14...90)
                    stepperRow("身高", value: $heightCm, unit: "cm", range: 130...220, step: 1)
                    stepperRow("体重", value: $weightKg, unit: "kg", range: 35...200, step: 0.5)
                }
                Section("活动量") {
                    Picker("活动量", selection: $activity) {
                        ForEach(ActivityLevel.allCases) { Text("\($0.rawValue)（\($0.hint)）").tag($0) }
                    }.pickerStyle(.inline).labelsHidden()
                }
                Section("目标") {
                    Picker("目标", selection: $goal) {
                        ForEach(FitnessGoal.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                }
                Section("推荐每日目标") {
                    LabeledContent("热量", value: "\(fmtNum(preview.kcal)) kcal")
                    LabeledContent("蛋白质", value: "\(fmtNum(preview.proteinG)) g")
                    LabeledContent("碳水", value: "\(fmtNum(preview.carbG)) g")
                    LabeledContent("脂肪", value: "\(fmtNum(preview.fatG)) g")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Color.bg)
            .navigationTitle("设置营养目标")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { complete() }
                        .tint(Theme.Color.accentCyan)
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func stepperRow(_ label: String, value: Binding<Double>, unit: String,
                            range: ClosedRange<Double>, step: Double) -> some View {
        Stepper(value: value, in: range, step: step) {
            Text("\(label) \(fmtNum(value.wrappedValue)) \(unit)")
        }
    }

    private func complete() {
        let g = NutritionGoal(isConfigured: true, sex: sex, age: age, heightCm: heightCm,
                              weightKg: weightKg, activity: activity, goal: goal)
        g.applyRecommendation()
        onComplete(g)
        dismiss()
    }
}

/// 目标微调（4.8）：手动覆盖任一目标值，或按资料重算。
struct NutritionGoalEditorView: View {
    @Bindable var goal: NutritionGoal
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            // 必要的 Form 用法：目标微调密集字段，sheet 隔离视觉影响。
            Form {
                Section("计算资料") {
                    Picker("性别", selection: $goal.sexRaw) {
                        ForEach(BioSex.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    Stepper("年龄 \(goal.age)", value: $goal.age, in: 14...90)
                    Stepper(value: $goal.heightCm, in: 130...220, step: 1) {
                        Text("身高 \(fmtNum(goal.heightCm)) cm")
                    }
                    Stepper(value: $goal.weightKg, in: 35...200, step: 0.5) {
                        Text("体重 \(fmtNum(goal.weightKg)) kg")
                    }
                    Picker("活动量", selection: $goal.activityRaw) {
                        ForEach(ActivityLevel.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    Picker("目标", selection: $goal.goalRaw) {
                        ForEach(FitnessGoal.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    Button("按资料重新计算") { goal.applyRecommendation() }
                }
                Section("每日目标（可手动微调）") {
                    targetField("热量 (kcal)", $goal.targetKcal)
                    targetField("蛋白质 (g)", $goal.targetProteinG)
                    targetField("碳水 (g)", $goal.targetCarbG)
                    targetField("脂肪 (g)", $goal.targetFatG)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Color.bg)
            .navigationTitle("调整目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { save() }.tint(Theme.Color.accentCyan)
                }
            }
        }
    }

    private func targetField(_ label: String, _ value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                .frame(width: 90)
        }
    }

    private func save() {
        goal.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }
}
