import Foundation

/// 单个动作的 PR 摘要。
struct PRSummary: Equatable {
    let exerciseKey: String
    let weightKg: Double
    let reps: Int
    let date: Date
    /// 历史第二高 PR（不同日期），用于「较上次 PR +X」差值；可能为 nil。
    let previousBestKg: Double?
}

enum PRStats {
    /// 一次遍历得到每个 `historyKey` 的最大 PR 重量（动作库列表用）。
    /// 取所有已结束、未软删训练里 reps>0 组的最大 `weightKg`；O(workouts×ex×sets) 一次，行查 O(1)。
    static func maxWeightByKey(in workouts: [Workout]) -> [String: Double] {
        var map: [String: Double] = [:]
        for w in workouts where w.deletedAt == nil && w.endedAt != nil {
            for ex in w.exercises {
                let key = ex.historyKey
                for s in ex.sets {
                    guard let wt = s.weightKg, let r = s.reps, r > 0 else { continue }
                    if let cur = map[key] { if wt > cur { map[key] = wt } } else { map[key] = wt }
                }
            }
        }
        return map
    }

    /// 返回某动作（按 `WorkoutExercise.historyKey` 匹配）的最新 PR 摘要。
    /// 规则：取所有已结束、未软删训练中重量最大的一组；若有同等重量，取日期更近者。
    /// previousBestKg = 排除「PR 当日」的其他记录里的最大重量。
    static func latestPR(for exerciseKey: String, in workouts: [Workout]) -> PRSummary? {
        var best: (w: Double, r: Int, d: Date)?
        var allWeightsByDay: [(weight: Double, day: Date)] = []

        for w in workouts where w.deletedAt == nil && w.endedAt != nil {
            for ex in w.exercises where ex.historyKey == exerciseKey {
                for s in ex.sets {
                    guard let wt = s.weightKg, let r = s.reps, r > 0 else { continue }
                    allWeightsByDay.append((wt, w.startedAt))
                    if let cur = best {
                        if wt > cur.w || (wt == cur.w && w.startedAt > cur.d) {
                            best = (wt, r, w.startedAt)
                        }
                    } else {
                        best = (wt, r, w.startedAt)
                    }
                }
            }
        }

        guard let b = best else { return nil }
        let cal = Calendar.current
        let prevBest = allWeightsByDay
            .filter { !cal.isDate($0.day, inSameDayAs: b.d) }
            .map(\.weight)
            .max()
        return PRSummary(exerciseKey: exerciseKey, weightKg: b.w, reps: b.r, date: b.d, previousBestKg: prevBest)
    }
}
