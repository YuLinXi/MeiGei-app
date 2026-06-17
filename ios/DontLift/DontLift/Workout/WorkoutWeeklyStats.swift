import Foundation

/// 训练首页周聚合统计纯函数（design.md D2：即时 query，不入库）。
///
/// 「本周」= 本地时区当周周一 00:00 到次周一 00:00。
/// 训练量：每组 `weightKg * reps` 求和（缺值视为 0）。
/// 总组数：所有训练里全部 set 计数（不要求 completed，与现有 logging 视图一致）。
/// 总次数：本周训练 session 数（按 startedAt 落入本周）。
/// 平均时长：已结束训练的时长加权平均；未结束训练不计入。
struct WeeklyStats: Equatable {
    var volumeKg: Double
    var sessionCount: Int
    var setCount: Int
    var repCount: Int
    /// 平均时长（秒）。无已结束训练时为 0。
    var avgDurationSec: Double

    static let empty = WeeklyStats(volumeKg: 0, sessionCount: 0, setCount: 0, repCount: 0, avgDurationSec: 0)
}

enum WorkoutWeeklyStats {
    /// 计算给定参考日期所在「自然周（周一起）」的训练聚合。
    static func compute(workouts: [Workout], reference: Date = .now, calendar: Calendar = .currentMondayFirst) -> WeeklyStats {
        let (start, end) = weekBounds(for: reference, calendar: calendar)
        var stats = WeeklyStats.empty
        var totalSec: Double = 0
        for w in workouts {
            guard w.deletedAt == nil else { continue }
            guard w.startedAt >= start, w.startedAt < end else { continue }
            stats.sessionCount += 1
            for ex in w.exercises {
                // 训练量/总组数/总次数仅统计正式组（热身组不计入），口径同 PR/曲线。
                for s in ex.sets where s.countsForStats {
                    stats.setCount += 1
                    let kg = s.weightKg ?? 0
                    let reps = s.reps ?? 0
                    stats.volumeKg += kg * Double(reps)
                    stats.repCount += reps
                }
            }
            if let ended = w.endedAt {
                totalSec += ended.timeIntervalSince(w.timerStartedAt ?? w.startedAt)
            }
        }
        // 平均时长按「有结束时间的 session」加权平均。
        let endedCount = workouts.filter {
            $0.deletedAt == nil && $0.startedAt >= start && $0.startedAt < end && $0.endedAt != nil
        }.count
        stats.avgDurationSec = endedCount > 0 ? totalSec / Double(endedCount) : 0
        return stats
    }

    /// 取参考日期所在周一 00:00 到次周一 00:00。
    static func weekBounds(for date: Date, calendar: Calendar = .currentMondayFirst) -> (start: Date, end: Date) {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let start = calendar.date(from: comps) ?? calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
        return (start, end)
    }
}

extension Calendar {
    /// 本应用统一用「周一起算」的日历视图（与设计稿一致）。
    static var currentMondayFirst: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2 // 1=Sun, 2=Mon
        c.minimumDaysInFirstWeek = 4
        return c
    }
}
