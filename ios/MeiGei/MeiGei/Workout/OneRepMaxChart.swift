import SwiftUI
import Charts

/// 90 天 1RM 估算曲线（Epley 公式：1RM = w × (1 + r/30)）。
///
/// 输入是已聚合（按 historyKey 命中本动作）的训练集合。
/// 折线展示「每日峰值 1RM」，数据点 < 3 时显示占位文案。
struct OneRepMaxChart: View {
    let workouts: [Workout]
    let exerciseKey: String

    struct Point: Identifiable {
        let date: Date
        let estimated1RM: Double
        var id: Date { date }
    }

    private var points: [Point] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: .now) ?? .distantPast
        var byDay: [Date: Double] = [:]
        let cal = Calendar.current
        for w in workouts where w.deletedAt == nil && w.startedAt >= cutoff {
            for ex in w.exercises where ex.historyKey == exerciseKey {
                for set in ex.sets {
                    guard let kg = set.weightKg, let reps = set.reps, reps > 0 else { continue }
                    let oneRM = kg * (1 + Double(reps) / 30.0)
                    let day = cal.startOfDay(for: w.startedAt)
                    byDay[day] = max(byDay[day] ?? 0, oneRM)
                }
            }
        }
        return byDay.map { Point(date: $0.key, estimated1RM: $0.value) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("90D 1RM 估算").eyebrowStyle()
            if points.count < 3 {
                placeholder
            } else {
                chart
            }
        }
        .cardStyle()
    }

    private var placeholder: some View {
        HStack {
            Image(systemName: "chart.xyaxis.line")
                .foregroundStyle(Theme.Color.muted)
            Text("数据不足 · 至少需要 3 次记录")
                .font(Theme.Font.body(size: 13))
                .foregroundStyle(Theme.Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 120)
    }

    private var chart: some View {
        let cyan = Theme.Color.accentCyan
        let last = points.last
        return Chart {
            ForEach(points) { p in
                AreaMark(x: .value("日期", p.date), y: .value("1RM", p.estimated1RM))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(.linearGradient(
                        colors: [cyan.opacity(0.35), cyan.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("日期", p.date), y: .value("1RM", p.estimated1RM))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(cyan)
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }
            if let last {
                PointMark(x: .value("日期", last.date), y: .value("1RM", last.estimated1RM))
                    .foregroundStyle(cyan)
                    .symbolSize(80)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(Theme.Color.border.opacity(0.5))
                AxisValueLabel().foregroundStyle(Theme.Color.muted)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(Theme.Color.border.opacity(0.3))
                AxisValueLabel().foregroundStyle(Theme.Color.muted)
            }
        }
        .frame(height: 160)
    }
}
