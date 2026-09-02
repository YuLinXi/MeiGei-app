import Foundation

/// 单个桶（L1 肌群或「其他」）在一个区间内的负荷聚合。
/// `category` 为 nil 表示「其他」桶（无法归组的动作），仅非零时展示、不参与排序与对比。
struct MuscleLoadEntry: Equatable, Identifiable {
    var category: ExerciseCategory?
    var workingSets: Int
    var volumeKg: Double

    var id: String { category?.rawValue ?? "other" }
}

/// 某肌群在一个区间内的动作贡献明细行。
struct MuscleLoadContribution: Equatable, Identifiable {
    var historyKey: String
    var exerciseName: String
    var workingSets: Int
    var volumeKg: Double

    var id: String { historyKey }
}

/// 肌群负荷快照（值类型，由 `WorkoutHistoryStore` 投影构建，视图只读）。
/// 覆盖当前周与上一完整周两套看板 + 基准 + 明细，复盘页切周无需重算。
struct MuscleLoadSnapshot: Equatable {
    /// 当前周起点（周一 00:00），用于视图判定快照是否跨周过期。
    var weekStart: Date
    /// 本周看板（八肌群 + 非零时的「其他」）。
    var board: [MuscleLoadEntry]
    /// 本周的对比基准：上周同期截断。
    var baseline: [MuscleLoadEntry]
    /// 上一完整周看板（复盘页切周）。
    var previousBoard: [MuscleLoadEntry]
    /// 上一完整周的对比基准：上上周整周。
    var previousBaseline: [MuscleLoadEntry]
    /// 近 4 个自然周（含本周，时间升序）每桶有效组数序列。
    var series: [ExerciseCategory?: [Int]]
    /// 本周各桶贡献明细。
    var contributions: [ExerciseCategory?: [MuscleLoadContribution]]
    /// 上一完整周各桶贡献明细。
    var previousContributions: [ExerciseCategory?: [MuscleLoadContribution]]

    static let empty = MuscleLoadSnapshot(
        weekStart: .distantPast,
        board: [], baseline: [], previousBoard: [], previousBaseline: [],
        series: [:], contributions: [:], previousContributions: [:]
    )
}

/// 肌群周负荷聚合纯函数（即时重算、不入库）。
///
/// 口径与首页 hero / PR / 历史曲线一致：仅 `countsForStats`（已完成且非热身）的正式组计 1 有效组，
/// 递减组按父组计 1 组、训练量按 segments 展开；软删训练不计入。
/// 归组两段式：优先训练记录的动作 `primaryMuscle` 快照；缺失时回退动作库按 code/name 解析；
/// 仍无法归组的进「其他」。非解剖类（有氧/功能性/热身拉伸）动作不计入任何桶。
enum MuscleLoadAggregator {

    /// 解剖类八个 L1 肌群的固定展示顺序之外的排序键：按有效组数降序。
    static let anatomicalCategories: [ExerciseCategory] = ExerciseCategory.allCases.filter(\.isAnatomical)

    // MARK: - 区间聚合

    /// 聚合 `[start, end)` 区间内的肌群负荷。返回八肌群（含 0 组）与「其他」（仅非零时出现）。
    static func load(workouts: [Workout], in range: Range<Date>) -> [MuscleLoadEntry] {
        var setsByCategory: [ExerciseCategory?: Int] = [:]
        var volumeByCategory: [ExerciseCategory?: Double] = [:]

        for workout in workouts {
            guard workout.deletedAt == nil else { continue }
            guard workout.startedAt >= range.lowerBound, workout.startedAt < range.upperBound else { continue }
            for exercise in workout.exercises {
                let sets = exercise.sets.filter(\.countsForStats)
                guard !sets.isEmpty else { continue }
                guard let bucket = bucket(for: exercise) else { continue } // 非解剖类：不计入
                setsByCategory[bucket, default: 0] += sets.count
                for set in sets {
                    for entry in set.statEntries {
                        volumeByCategory[bucket, default: 0] += (entry.weightKg ?? 0) * Double(entry.reps ?? 0)
                    }
                }
            }
        }

        var entries = anatomicalCategories.map { category in
            MuscleLoadEntry(category: category,
                            workingSets: setsByCategory[category] ?? 0,
                            volumeKg: volumeByCategory[category] ?? 0)
        }
        if let otherSets = setsByCategory[nil], otherSets > 0 {
            entries.append(MuscleLoadEntry(category: nil,
                                           workingSets: otherSets,
                                           volumeKg: volumeByCategory[nil] ?? 0))
        }
        return entries
    }

    /// 负荷板排序：有效组数降序，同数按肌群中文名稳定次序；「其他」永远沉底（由调用方决定是否展示）。
    static func sortedBoard(_ entries: [MuscleLoadEntry]) -> [MuscleLoadEntry] {
        entries.sorted { lhs, rhs in
            switch (lhs.category, rhs.category) {
            case (nil, nil): return false
            case (nil, _?): return false
            case (_?, nil): return true
            case let (l?, r?):
                if lhs.workingSets != rhs.workingSets { return lhs.workingSets > rhs.workingSets }
                return l.rawValue < r.rawValue
            }
        }
    }

    /// 某区间内的总有效组数（空态判断用）。
    static func totalWorkingSets(_ entries: [MuscleLoadEntry]) -> Int {
        entries.reduce(0) { $0 + $1.workingSets }
    }

    // MARK: - 周界与同期对比

    /// 参考日所在自然周（周一 00:00 起）。
    static func weekRange(for reference: Date = .now,
                          calendar: Calendar = .currentMondayFirst) -> Range<Date> {
        let (start, end) = WorkoutWeeklyStats.weekBounds(for: reference, calendar: calendar)
        return start..<end
    }

    /// 上一完整自然周。
    static func previousWeekRange(for reference: Date = .now,
                                  calendar: Calendar = .currentMondayFirst) -> Range<Date> {
        let current = weekRange(for: reference, calendar: calendar)
        let start = calendar.date(byAdding: .weekOfYear, value: -1, to: current.lowerBound) ?? current.lowerBound
        return start..<current.lowerBound
    }

    /// 同期对比基准：若参考区间是进行中的本周（reference 落在区间内），
    /// 取上一周「周一 00:00 起、与本周已流逝时长相同」的截断区间；完整周则取上一整周。
    static func sameOffsetPreviousWeekRange(for week: Range<Date>,
                                            reference: Date = .now,
                                            calendar: Calendar = .currentMondayFirst) -> Range<Date> {
        let previousStart = calendar.date(byAdding: .weekOfYear, value: -1, to: week.lowerBound) ?? week.lowerBound
        let previousEnd = calendar.date(byAdding: .weekOfYear, value: -1, to: week.upperBound) ?? week.upperBound
        guard reference >= week.lowerBound, reference < week.upperBound else {
            return previousStart..<previousEnd
        }
        let elapsed = reference.timeIntervalSince(week.lowerBound)
        let cutoff = min(previousStart + elapsed, previousEnd)
        return previousStart..<cutoff
    }

    // MARK: - 近 N 周趋势

    /// 近 `weeks` 个自然周（含参考周，按时间升序）每个肌群的周有效组数。
    /// 返回顺序与 `sortedBoard(load(workouts:in: weekRange))` 对齐由调用方自行处理。
    static func weeklySeries(workouts: [Workout],
                             weeks: Int,
                             reference: Date = .now,
                             calendar: Calendar = .currentMondayFirst) -> [ExerciseCategory?: [Int]] {
        let current = weekRange(for: reference, calendar: calendar)
        var series: [ExerciseCategory?: [Int]] = [:]
        for offset in stride(from: -(weeks - 1), through: 0, by: 1) {
            guard let start = calendar.date(byAdding: .weekOfYear, value: offset, to: current.lowerBound) else { continue }
            let range = start..<(calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? current.upperBound)
            for entry in load(workouts: workouts, in: range) {
                series[entry.category, default: []].append(entry.workingSets)
            }
        }
        // 保证每个桶都有等长序列（缺失周补 0）。
        let keys: [ExerciseCategory?] = anatomicalCategories + [nil]
        for key in keys where series[key] == nil {
            series[key] = Array(repeating: 0, count: weeks)
        }
        return series
    }

    // MARK: - 贡献明细
    /// 某肌群（或「其他」，category 传 nil）在区间内的动作贡献明细，按有效组数降序、再按名称稳定。
    static func contributions(workouts: [Workout],
                              in range: Range<Date>,
                              category: ExerciseCategory?) -> [MuscleLoadContribution] {
        var byKey: [String: (name: String, sets: Int, volume: Double)] = [:]
        for workout in workouts {
            guard workout.deletedAt == nil else { continue }
            guard workout.startedAt >= range.lowerBound, workout.startedAt < range.upperBound else { continue }
            for exercise in workout.exercises {
                guard bucket(for: exercise) == category else { continue }
                let sets = exercise.sets.filter(\.countsForStats)
                guard !sets.isEmpty else { continue }
                var volume = 0.0
                for set in sets {
                    for entry in set.statEntries {
                        volume += (entry.weightKg ?? 0) * Double(entry.reps ?? 0)
                    }
                }
                let key = exercise.historyKey
                let existing = byKey[key] ?? (name: exercise.displayExerciseName, sets: 0, volume: 0)
                byKey[key] = (name: existing.name,
                              sets: existing.sets + sets.count,
                              volume: existing.volume + volume)
            }
        }
        return byKey
            .map { MuscleLoadContribution(historyKey: $0.key,
                                          exerciseName: $0.value.name,
                                          workingSets: $0.value.sets,
                                          volumeKg: $0.value.volume) }
            .sorted {
                if $0.workingSets != $1.workingSets { return $0.workingSets > $1.workingSets }
                return $0.exerciseName < $1.exerciseName
            }
    }

    // MARK: - 归组

    /// 两段式归组：快照 `primaryMuscle` 优先；缺失/无法识别时回退动作库 code/name 解析。
    /// 原始分类先经 `ExerciseCategory.collapseL1` 收缩（二头/三头/前臂→手臂、小腿→腿、斜方肌→背）。
    /// 解析结果为非解剖类时返回外层 nil（不计入负荷板）；仍无法归组的返回「其他」（`.some(nil)`）。
    static func bucket(for exercise: WorkoutExercise) -> ExerciseCategory?? {
        if let snapshot = exercise.primaryMuscle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !snapshot.isEmpty,
           let category = ExerciseCategory(rawValue: ExerciseCategory.collapseL1(snapshot)) {
            // 显式双层 Optional：外层 nil = 非解剖类不计入；内层 nil = 「其他」桶。
            if !category.isAnatomical { return nil }
            return .some(category)
        }
        if let resolved = ExerciseLibrary.resolve(code: exercise.builtinExerciseCode,
                                                  name: exercise.exerciseName),
           let category = ExerciseCategory(rawValue: ExerciseCategory.collapseL1(resolved.category)) {
            if !category.isAnatomical { return nil }
            return .some(category)
        }
        return .some(nil)
    }

    // MARK: - 快照构建

    /// 由全量未删除训练一次性构建肌群负荷快照（供 history store 投影复用）。
    static func snapshot(workouts: [Workout],
                         reference: Date = .now,
                         calendar: Calendar = .currentMondayFirst) -> MuscleLoadSnapshot {
        let currentWeek = weekRange(for: reference, calendar: calendar)
        let previousWeek = previousWeekRange(for: reference, calendar: calendar)
        let baselineRange = sameOffsetPreviousWeekRange(for: currentWeek, reference: reference, calendar: calendar)
        let previousBaselineRange = previousWeekRange(
            for: calendar.date(byAdding: .day, value: -1, to: currentWeek.lowerBound) ?? reference,
            calendar: calendar)

        let buckets: [ExerciseCategory?] = anatomicalCategories + [nil]
        var currentByBucket: [ExerciseCategory?: [MuscleLoadContribution]] = [:]
        var previousByBucket: [ExerciseCategory?: [MuscleLoadContribution]] = [:]
        for bucket in buckets {
            let current = contributions(workouts: workouts, in: currentWeek, category: bucket)
            if !current.isEmpty { currentByBucket[bucket] = current }
            let previous = contributions(workouts: workouts, in: previousWeek, category: bucket)
            if !previous.isEmpty { previousByBucket[bucket] = previous }
        }

        return MuscleLoadSnapshot(
            weekStart: currentWeek.lowerBound,
            board: sortedBoard(load(workouts: workouts, in: currentWeek)),
            baseline: load(workouts: workouts, in: baselineRange),
            previousBoard: sortedBoard(load(workouts: workouts, in: previousWeek)),
            previousBaseline: load(workouts: workouts, in: previousBaselineRange),
            series: weeklySeries(workouts: workouts, weeks: 4, reference: reference, calendar: calendar),
            contributions: currentByBucket,
            previousContributions: previousByBucket
        )
    }

    /// 看板中某桶的有效组数（缺失桶按 0）。
    static func sets(of category: ExerciseCategory?, in board: [MuscleLoadEntry]) -> Int {
        board.first { $0.category == category }?.workingSets ?? 0
    }
}
