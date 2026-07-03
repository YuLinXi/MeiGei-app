import Foundation

/// 训练首页周聚合统计纯函数（design.md D2：即时 query，不入库）。
///
/// 「本周」= 本地时区当周周一 00:00 到次周一 00:00。
/// 训练量：每组 `weightKg * reps` 求和（缺值视为 0）。
/// 总组数：所有训练里全部 set 计数（不要求 completed，与现有 logging 视图一致）。
/// 总次数：本周训练 session 数（按 startedAt 落入本周）。
struct WeeklyStats: Equatable {
    var volumeKg: Double
    var sessionCount: Int
    var setCount: Int
    var repCount: Int

    static let empty = WeeklyStats(volumeKg: 0, sessionCount: 0, setCount: 0, repCount: 0)
}

struct WeekTrainingDayStatus: Identifiable, Equatable, Hashable {
    var date: Date
    var weekdayIndex: Int
    var sessionCount: Int
    var isToday: Bool

    var id: Date { date }
    var isCompleted: Bool { sessionCount > 0 }
}

enum WorkoutWeeklyStats {
    /// 计算给定参考日期所在「自然周（周一起）」的训练聚合。
    static func compute(workouts: [Workout], reference: Date = .now, calendar: Calendar = .currentMondayFirst) -> WeeklyStats {
        let (start, end) = weekBounds(for: reference, calendar: calendar)
        var stats = WeeklyStats.empty
        for w in workouts {
            guard w.deletedAt == nil else { continue }
            guard w.startedAt >= start, w.startedAt < end else { continue }
            stats.sessionCount += 1
            for ex in w.exercises {
                // 训练量/总组数/总次数仅统计正式组（热身组不计入），口径同 PR/曲线。
                for s in ex.sets where s.countsForStats {
                    stats.setCount += 1
                    for entry in s.statEntries {
                        let kg = entry.weightKg ?? 0
                        let reps = entry.reps ?? 0
                        stats.volumeKg += kg * Double(reps)
                        stats.repCount += reps
                    }
                }
            }
        }
        return stats
    }

    /// 取参考日期所在周一 00:00 到次周一 00:00。
    static func weekBounds(for date: Date, calendar: Calendar = .currentMondayFirst) -> (start: Date, end: Date) {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let start = calendar.date(from: comps) ?? calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
        return (start, end)
    }

    static func dayStatuses(workouts: [Workout], reference: Date = .now, calendar: Calendar = .currentMondayFirst) -> [WeekTrainingDayStatus] {
        let (start, end) = weekBounds(for: reference, calendar: calendar)
        var countsByDay: [Date: Int] = [:]
        for workout in workouts {
            guard workout.isFinished else { continue }
            guard workout.startedAt >= start, workout.startedAt < end else { continue }
            let day = calendar.startOfDay(for: workout.startedAt)
            countsByDay[day, default: 0] += 1
        }
        let today = calendar.startOfDay(for: reference)
        return (0..<7).compactMap { index in
            guard let day = calendar.date(byAdding: .day, value: index, to: start) else { return nil }
            let normalized = calendar.startOfDay(for: day)
            return WeekTrainingDayStatus(
                date: normalized,
                weekdayIndex: index,
                sessionCount: countsByDay[normalized] ?? 0,
                isToday: calendar.isDate(normalized, inSameDayAs: today)
            )
        }
    }
}

extension Calendar {
    /// 本应用统一用「周一起算」的日历视图（与设计稿一致）。
    nonisolated static var currentMondayFirst: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2 // 1=Sun, 2=Mon
        c.minimumDaysInFirstWeek = 4
        return c
    }
}
