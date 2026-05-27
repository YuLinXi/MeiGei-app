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

    /// 在给定时间窗内新出现的 PR：按 `historyKey` 分组，找窗口内最大重量，
    /// 且严格大于「窗口外历史最大」。窗口由 `[since, until)` 描述（含 since，不含 until）。
    /// 返回按重量降序排列；首项可作为「★ NEW PR」高亮卡。
    static func newPRs(in workouts: [Workout], since: Date, until: Date) -> [PRSummary] {
        // 先把所有训练拆解到 (key, weight, reps, day)
        struct Row { let key: String; let name: String; let weight: Double; let reps: Int; let day: Date }
        var rows: [Row] = []
        for w in workouts where w.deletedAt == nil && w.endedAt != nil {
            for ex in w.exercises {
                let key = ex.historyKey
                for s in ex.sets {
                    if let wt = s.weightKg, let r = s.reps, r > 0 {
                        rows.append(Row(key: key, name: ex.exerciseName, weight: wt, reps: r, day: w.startedAt))
                    }
                }
            }
        }

        // 按 key 分组
        var byKey: [String: [Row]] = [:]
        for r in rows { byKey[r.key, default: []].append(r) }

        var out: [PRSummary] = []
        for (key, items) in byKey {
            let inWindow = items.filter { $0.day >= since && $0.day < until }
            guard let winMax = inWindow.max(by: { $0.weight < $1.weight }) else { continue }
            let outWindow = items.filter { $0.day < since || $0.day >= until }
            let priorMax = outWindow.map(\.weight).max()
            // 必须严格大于窗口外的历史最大，才算窗口内新 PR
            if (priorMax ?? -.infinity) < winMax.weight {
                out.append(PRSummary(
                    exerciseKey: key,
                    weightKg: winMax.weight,
                    reps: winMax.reps,
                    date: winMax.day,
                    previousBestKg: priorMax
                ))
            }
        }
        return out.sorted { $0.weightKg > $1.weightKg }
    }
}
