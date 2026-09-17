import Foundation

nonisolated enum WorkoutHistoryProjection {
    struct Projection: Sendable {
        var home: HomeWorkoutSnapshot
        var calendarDays: [Date: WorkoutCalendarDaySummary]
        var exercisePRs: [String: PRSummary]
        var exerciseHistories: [String: ExerciseHistorySnapshot]
        var workoutRecords: [UUID: [PersonalRecord]]
        var bestWeightByExerciseKey: [String: Double]
        var planLookup: PlanHistoryLookup
        var planUsage: [UUID: PlanUsageSummary]
        var profile: ProfileWorkoutSnapshot
        var muscleLoad: MuscleLoadSnapshot
        var scale: DataScale
    }

    struct DataScale: Sendable {
        var workouts: Int
        var finished: Int
        var active: Int
        var pending: Int
        var exercises: Int
        var sets: Int
    }

    static func build(workouts: [HistoryWorkout]) -> Projection {
        let finishedDesc = workouts.filter(\.isFinished)
        let finishedAsc = finishedDesc.reversed()

        var exerciseCount = 0
        var setCount = 0
        var pendingCount = 0
        for w in workouts {
            if w.syncStatusRaw != "synced" { pendingCount += 1 }
            exerciseCount += w.exercises.count
            setCount += w.completedStatEntryCount
        }

        var prByWorkoutId: [UUID: PRBadge] = [:]
        var recordsByWorkoutId: [UUID: [PersonalRecord]] = [:]
        var bestByKey: [String: Double] = [:]
        var assistanceHistory: [(date: Date, value: ExerciseWeightSemantics.Performance)] = []
        var exerciseBest: [String: (weight: Double, reps: Int, date: Date)] = [:]
        var allWeightsByKey: [String: [(weight: Double, date: Date)]] = [:]
        var historyPointsByKey: [String: [ExerciseHistoryPoint]] = [:]

        for w in finishedAsc {
            var records: [PersonalRecord] = []
            var seenKeys = Set<String>()
            var perWorkoutPoint: [String: (maxWeight: Double?, lastWeight: Double?, lastReps: Int?)] = [:]

            for ex in w.exercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                let key = ex.historyKey
                let sortedSets = ex.sets.sorted { $0.setIndex < $1.setIndex }
                let counted = sortedSets.filter(\.countsForStats)
                let statEntries = counted.flatMap(\.statEntries)
                if ex.isAssistedWeight {
                    let prior = assistanceHistory.filter { $0.date < w.startedAt }.map(\.value)
                    if let best = ex.assistancePerformances.filter({ ExerciseWeightSemantics.isAssistanceBreakthrough($0, prior: prior) }).min(by: { $0.weight < $1.weight }), seenKeys.insert(key).inserted {
                        records.append(PersonalRecord(exerciseKey: key, exerciseName: ex.displayExerciseName, weightKg: best.weight,
                                                      previousBestKg: prior.filter { $0.weight > best.weight && $0.reps <= best.reps }.map(\.weight).min()))
                    }
                }
                if !ex.isAssistedWeight, let maxWeight = statEntries.compactMap(\.weightKg).max(), !seenKeys.contains(key) {
                    let prior = bestByKey[key]
                    if prior == nil || maxWeight > prior! {
                        records.append(PersonalRecord(
                            exerciseKey: key,
                            exerciseName: ex.displayExerciseName,
                            weightKg: maxWeight,
                            previousBestKg: prior
                        ))
                        seenKeys.insert(key)
                    }
                }

                for entry in statEntries {
                    guard let weight = entry.weightKg, let reps = entry.reps, reps > 0 else { continue }
                    if ex.isAssistedWeight && (!weight.isFinite || weight < 0) { continue }
                    allWeightsByKey[key, default: []].append((weight, w.startedAt))
                    if let cur = exerciseBest[key] {
                        if ExerciseWeightSemantics.isBetter(weight, than: cur.weight, assisted: ex.isAssistedWeight) || (weight == cur.weight && (ex.isAssistedWeight && reps > cur.reps || ((!ex.isAssistedWeight || reps == cur.reps) && w.startedAt > cur.date))) {
                            exerciseBest[key] = (weight, reps, w.startedAt)
                        }
                    } else {
                        exerciseBest[key] = (weight, reps, w.startedAt)
                    }
                }

                let weights = statEntries.compactMap(\.weightKg)
                if let maxWeight = ex.isAssistedWeight ? weights.filter({ $0.isFinite && $0 >= 0 }).min() : weights.max() {
                    let previous = bestByKey[key] ?? maxWeight
                    bestByKey[key] = ex.isAssistedWeight ? min(previous, maxWeight) : max(previous, maxWeight)
                    var point = perWorkoutPoint[key] ?? (nil, nil, nil)
                    point.maxWeight = ex.isAssistedWeight ? min(point.maxWeight ?? maxWeight, maxWeight) : max(point.maxWeight ?? maxWeight, maxWeight)
                    perWorkoutPoint[key] = point
                } else if perWorkoutPoint[key] == nil {
                    perWorkoutPoint[key] = (nil, nil, nil)
                }

                if let last = counted.last(where: {
                    let summary = $0.summaryWeightReps
                    return summary.weightKg != nil && summary.reps != nil
                }) {
                    let summary = last.summaryWeightReps
                    var point = perWorkoutPoint[key] ?? (nil, nil, nil)
                    point.lastWeight = summary.weightKg
                    point.lastReps = summary.reps
                    perWorkoutPoint[key] = point
                }
            }

            assistanceHistory += w.exercises.filter(\.isAssistedWeight).flatMap(\.assistancePerformances).map { (w.startedAt, $0) }
            if let first = records.first {
                prByWorkoutId[w.localId] = PRBadge(name: first.exerciseName, weightKg: first.weightKg, isAssistedWeight: ExerciseWeightSemantics.isAssisted(first.exerciseKey))
            }
            if !records.isEmpty {
                recordsByWorkoutId[w.localId] = records
            }
            for (key, point) in perWorkoutPoint {
                historyPointsByKey[key, default: []].append(ExerciseHistoryPoint(
                    date: w.startedAt,
                    maxWeightKg: point.maxWeight,
                    lastSetWeightKg: point.lastWeight,
                    lastSetReps: point.lastReps
                ))
            }
        }

        let cal = Calendar.current
        var exercisePRs: [String: PRSummary] = [:]
        for (key, best) in exerciseBest {
            let previous = (allWeightsByKey[key] ?? [])
                .filter { !cal.isDate($0.date, inSameDayAs: best.date) }
                .map(\.weight)
            let prevBest = ExerciseWeightSemantics.isAssisted(key) ? previous.min() : previous.max()
            exercisePRs[key] = PRSummary(
                exerciseKey: key,
                weightKg: best.weight,
                reps: best.reps,
                date: best.date,
                previousBestKg: prevBest
            )
        }

        var exerciseHistories: [String: ExerciseHistorySnapshot] = [:]
        for (key, points) in historyPointsByKey {
            exerciseHistories[key] = ExerciseHistorySnapshot(
                exerciseKey: key,
                points: points.sorted { $0.date < $1.date },
                pr: exercisePRs[key]
            )
        }

        let now = Date.now
        let calendar = Calendar.currentMondayFirst
        let weekBounds = WorkoutWeeklyStats.weekBounds(for: now, calendar: calendar)
        func rowSummary(for w: HistoryWorkout) -> WorkoutRowSummary {
            let duration = w.endedAt.map { $0.timeIntervalSince(w.timerStartedAt ?? w.startedAt) }
            let volume = w.exercises.flatMap(\.sets).reduce(0.0) { acc, set in
                guard set.countsForStats else { return acc }
                return acc + set.statEntries.reduce(0.0) { entryAcc, entry in
                    entryAcc + entry.volumeKg
                }
            }
            return WorkoutRowSummary(
                id: w.localId,
                title: w.title ?? "训练",
                startedAt: w.startedAt,
                durationSec: duration,
                exerciseCount: w.exercises.count,
                setCount: w.completedStatEntryCount,
                volumeKg: volume,
                pr: prByWorkoutId[w.localId]
            )
        }
        let weekWorkouts = finishedDesc
            .filter { $0.startedAt >= weekBounds.start && $0.startedAt < weekBounds.end }
            .map(rowSummary)
        let calendarDays = buildCalendarDays(
            from: finishedDesc,
            prByWorkoutId: prByWorkoutId,
            rowSummary: rowSummary,
            calendar: calendar
        )
        let today = calendar.startOfDay(for: now)
        let todayCompletedWorkoutCount = calendarDays[today]?.workoutCount ?? 0
        let currentTrainingStreakDays = currentTrainingStreakDays(
            in: finishedDesc,
            reference: now,
            calendar: calendar
        )

        let cutoff = Date.now.addingTimeInterval(-14 * 86_400)
        let recentPlanIdsInOrder = finishedDesc
            .filter { $0.startedAt > cutoff }
            .compactMap(\.planId)
        let recentPlanIds = Set(recentPlanIdsInOrder)
        let activePlanId = recentPlanIdsInOrder.first

        let home = HomeWorkoutSnapshot(
            currentWeekStats: WorkoutWeeklyStats.compute(
                values: finishedDesc,
                reference: now,
                calendar: calendar
            ),
            weekWorkouts: Array(weekWorkouts),
            weekTrainingDays: WorkoutWeeklyStats.dayStatuses(
                values: finishedDesc,
                reference: now,
                calendar: calendar
            ),
            todayCompletedWorkoutCount: todayCompletedWorkoutCount,
            currentTrainingStreakDays: currentTrainingStreakDays,
            recentPlanIds: recentPlanIds,
            activePlanId: activePlanId,
            prByWorkoutId: prByWorkoutId
        )

        let profile = ProfileWorkoutSnapshot(totalWorkouts: finishedDesc.count)

        var planUsage: [UUID: PlanUsageSummary] = [:]
        for w in finishedDesc {
            guard let planId = w.planId else { continue }
            var summary = planUsage[planId] ?? .empty
            summary.completedCount += 1
            if summary.lastTrainedAt == nil || w.startedAt > summary.lastTrainedAt! {
                summary.lastTrainedAt = w.startedAt
            }
            planUsage[planId] = summary
        }

        let planLookup = PlanHistoryLookup.build(values: finishedDesc)
        let muscleLoad = MuscleLoadAggregator.snapshot(values: finishedDesc,
                                                       reference: now,
                                                       calendar: calendar)
        let scale = DataScale(
            workouts: workouts.count,
            finished: finishedDesc.count,
            active: workouts.filter(\.isActive).count,
            pending: pendingCount,
            exercises: exerciseCount,
            sets: setCount
        )

        return Projection(
            home: home,
            calendarDays: calendarDays,
            exercisePRs: exercisePRs,
            exerciseHistories: exerciseHistories,
            workoutRecords: recordsByWorkoutId,
            bestWeightByExerciseKey: bestByKey,
            planLookup: planLookup,
            planUsage: planUsage,
            profile: profile,
            muscleLoad: muscleLoad,
            scale: scale
        )
    }

    private static func buildCalendarDays(
        from workouts: [HistoryWorkout],
        prByWorkoutId: [UUID: PRBadge],
        rowSummary: (HistoryWorkout) -> WorkoutRowSummary,
        calendar: Calendar = .currentMondayFirst
    ) -> [Date: WorkoutCalendarDaySummary] {
        var days: [Date: WorkoutCalendarDaySummary] = [:]
        for workout in workouts {
            let day = calendar.startOfDay(for: workout.startedAt)
            var summary = days[day] ?? WorkoutCalendarDaySummary(
                date: day,
                workouts: [],
                setCount: 0,
                volumeKg: 0,
                hasPR: false
            )
            summary.workouts.append(rowSummary(workout))
            summary.hasPR = summary.hasPR || prByWorkoutId[workout.localId] != nil
            for exercise in workout.exercises {
                for set in exercise.sets where set.countsForStats {
                    summary.setCount += 1
                    summary.volumeKg += set.statEntries.reduce(0.0) { acc, entry in
                        acc + entry.volumeKg
                    }
                }
            }
            days[day] = summary
        }
        return days
    }

    private static func currentTrainingStreakDays(
        in workouts: [HistoryWorkout],
        reference: Date,
        calendar: Calendar
    ) -> Int {
        let completedDays = Set(workouts.map { calendar.startOfDay(for: $0.startedAt) })
        var cursor = calendar.startOfDay(for: reference)
        var count = 0
        while completedDays.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

}
