import SwiftUI

/// 当日达成进度（4.8）：热量 + 三大宏量已摄入 / 目标 / 差额。
struct TargetProgressSection: View {
    let totals: NutritionTotals
    let targets: DailyTargets
    let onEditTargets: () -> Void

    var body: some View {
        Section {
            MacroBar(name: "热量", current: totals.kcal, target: targets.kcal, unit: "kcal", tint: .orange)
            MacroBar(name: "蛋白质", current: totals.proteinG, target: targets.proteinG, unit: "g", tint: .red)
            MacroBar(name: "碳水", current: totals.carbG, target: targets.carbG, unit: "g", tint: .blue)
            MacroBar(name: "脂肪", current: totals.fatG, target: targets.fatG, unit: "g", tint: .yellow)
        } header: {
            HStack {
                Text("今日目标")
                Spacer()
                Button("调整目标", action: onEditTargets).font(.caption)
            }
        } footer: {
            Text("纤维 \(fmtNum(totals.fiberG))g · 糖 \(fmtNum(totals.sugarG))g · 钠 \(fmtNum(totals.sodiumMg))mg")
        }
    }
}

private struct MacroBar: View {
    let name: String
    let current: Double
    let target: Double
    let unit: String
    let tint: Color

    private var ratio: Double { target > 0 ? min(current / target, 1) : 0 }
    private var remaining: Double { target - current }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                Spacer()
                Text("\(fmtNum(current)) / \(fmtNum(target)) \(unit)")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ProgressView(value: ratio).tint(tint)
            Text(remaining >= 0 ? "还差 \(fmtNum(remaining)) \(unit)" : "已超 \(fmtNum(-remaining)) \(unit)")
                .font(.caption2)
                .foregroundStyle(remaining >= 0 ? .secondary : Color.red)
        }
        .padding(.vertical, 2)
    }
}
