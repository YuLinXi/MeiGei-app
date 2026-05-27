import SwiftUI

/// 当日宏量进度环 + 三大宏量 + 水 4 条进度条（Screen 07）。
/// - 圆环：当日热量 / 目标热量（cyan）。
/// - 蛋白：accentCyan；碳水：accentCyan；脂肪：macroFat；水：240° 蓝色（仅在本视图内部使用，不外泄为 token）。
struct MacroRingView: View {
    let totals: NutritionTotals
    let targets: DailyTargets
    /// 水（毫升）。MVP 暂未持久化水分摄入，默认占位 0。
    let waterMl: Double
    let targetWaterMl: Double

    /// 240° 蓝色，仅限本视图「水」语义；其它视图引用会被 code review 拦截。
    private var waterColor: Color {
        Color(hue: 240.0 / 360.0, saturation: 0.55, brightness: 0.85)
    }

    private var kcalProgress: Double {
        guard targets.kcal > 0 else { return 0 }
        return min(1.0, totals.kcal / targets.kcal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack(spacing: Theme.Spacing.lg) {
                ring
                kcalSummary
                Spacer()
            }
            VStack(spacing: Theme.Spacing.md) {
                bar(label: "蛋白", value: totals.proteinG, goal: targets.proteinG, unit: "g", color: Theme.Color.accentCyan)
                bar(label: "碳水", value: totals.carbG,    goal: targets.carbG,    unit: "g", color: Theme.Color.accentCyan)
                bar(label: "脂肪", value: totals.fatG,     goal: targets.fatG,     unit: "g", color: Theme.Color.macroFat)
                bar(label: "水",   value: waterMl,         goal: targetWaterMl,    unit: "ml", color: waterColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Theme.Color.border, lineWidth: 8)
            Circle()
                .trim(from: 0, to: kcalProgress)
                .stroke(Theme.Color.accentCyan, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(String(Int(totals.kcal.rounded())))
                    .numStyle(size: 22, weight: .bold)
                    .foregroundStyle(Theme.Color.fg)
                Text("kcal")
                    .font(Theme.Font.mono(size: 10))
                    .foregroundStyle(Theme.Color.muted)
            }
        }
        .frame(width: 96, height: 96)
    }

    private var kcalSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TARGET · 当日热量").eyebrowStyle()
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(String(Int(totals.kcal.rounded())))
                    .numStyle(size: 26, weight: .bold)
                    .foregroundStyle(Theme.Color.fg)
                Text("/ \(Int(targets.kcal.rounded())) kcal")
                    .font(Theme.Font.mono(size: 12))
                    .foregroundStyle(Theme.Color.fg2)
            }
            let remaining = max(0, targets.kcal - totals.kcal)
            Text("剩余 \(Int(remaining.rounded())) kcal")
                .font(Theme.Font.body(size: 12))
                .foregroundStyle(Theme.Color.fg2)
        }
    }

    private func bar(label: String, value: Double, goal: Double, unit: String, color: Color) -> some View {
        let progress = goal > 0 ? min(1.0, value / goal) : 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline) {
                Text(label).font(Theme.Font.body(size: 12, weight: .semibold)).foregroundStyle(Theme.Color.fg)
                Spacer()
                Text("\(Int(value.rounded())) / \(Int(goal.rounded())) \(unit)")
                    .font(Theme.Font.mono(size: 11))
                    .foregroundStyle(Theme.Color.fg2)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Color.surface2).frame(height: 6)
                    Capsule().fill(color).frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}
