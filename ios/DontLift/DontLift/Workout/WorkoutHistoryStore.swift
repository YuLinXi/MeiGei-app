import Foundation
import Observation
import SwiftData

enum WorkoutHistoryRefreshReason: String {
    case appLaunch
    case login
    case syncCompleted
    case workoutChanged
    case manual
}

struct PRBadge: Equatable, Hashable {
    var name: String
    var weightKg: Double
}

struct SetSnapshot: Equatable, Hashable {
    var weightKg: Double?
    var reps: Int?
    var setTypeRaw: String = WorkoutSetType.working.rawValue
    var segments: [WorkoutSetSegment] = []
}

struct ExerciseHistoryPoint: Equatable, Hashable {
    var date: Date
    var maxWeightKg: Double?
    var lastSetWeightKg: Double?
    var lastSetReps: Int?
}

struct ExerciseHistorySnapshot: Equatable {
    var exerciseKey: String
    var points: [ExerciseHistoryPoint]
    var pr: PRSummary?

    static func empty(_ key: String) -> ExerciseHistorySnapshot {
        ExerciseHistorySnapshot(exerciseKey: key, points: [], pr: nil)
    }

    var isEmpty: Bool { points.isEmpty }
    var last: ExerciseHistoryPoint? { points.last }
}

struct WorkoutRowSummary: Identifiable, Equatable, Hashable {
    var id: UUID
    var title: String
    var startedAt: Date
    var durationSec: TimeInterval?
    var exerciseCount: Int
    var setCount: Int
    var volumeKg: Double
    var pr: PRBadge?
}

struct HomeWorkoutSnapshot: Equatable {
    var currentWeekStats: WeeklyStats
    var weekWorkouts: [WorkoutRowSummary]
    var weekTrainingDays: [WeekTrainingDayStatus]
    var recentPlanIds: Set<UUID>
    var activePlanId: UUID?
    var prByWorkoutId: [UUID: PRBadge]

    static let empty = HomeWorkoutSnapshot(
        currentWeekStats: .empty,
        weekWorkouts: [],
        weekTrainingDays: WorkoutWeeklyStats.dayStatuses(workouts: [], reference: .now, calendar: .currentMondayFirst),
        recentPlanIds: [],
        activePlanId: nil,
        prByWorkoutId: [:]
    )
}

struct WorkoutCalendarDaySummary: Identifiable, Equatable, Hashable {
    var date: Date
    var workouts: [WorkoutRowSummary]
    var setCount: Int
    var volumeKg: Double
    var hasPR: Bool

    var id: Date { date }
    var workoutCount: Int { workouts.count }
}

struct WorkoutCalendarDayCell: Identifiable, Equatable, Hashable {
    var date: Date
    var isInDisplayedMonth: Bool
    var isToday: Bool
    var summary: WorkoutCalendarDaySummary?

    var id: Date { date }
}

struct WorkoutCalendarMonthSnapshot: Equatable {
    var monthStart: Date
    var days: [WorkoutCalendarDayCell]
    var workoutCount: Int
    var setCount: Int
    var volumeKg: Double

    static func empty(monthStart: Date) -> WorkoutCalendarMonthSnapshot {
        WorkoutCalendarMonthSnapshot(
            monthStart: monthStart,
            days: [],
            workoutCount: 0,
            setCount: 0,
            volumeKg: 0
        )
    }
}

struct WorkoutCalendarMonthArchiveItem: Identifiable, Equatable, Hashable {
    var monthStart: Date
    var trainingDayCount: Int
    var workoutCount: Int
    var setCount: Int
    var volumeKg: Double
    var activeDayNumbers: Set<Int>

    var id: Date { monthStart }
}

struct WorkoutCalendarYearArchiveGroup: Identifiable, Equatable, Hashable {
    var year: Int
    var months: [WorkoutCalendarMonthArchiveItem]

    var id: Int { year }
}

struct ProfileWorkoutSnapshot: Equatable {
    var totalWorkouts: Int

    static let empty = ProfileWorkoutSnapshot(totalWorkouts: 0)
}

struct PlanUsageSummary: Equatable, Hashable {
    var completedCount: Int
    var lastTrainedAt: Date?

    static let empty = PlanUsageSummary(completedCount: 0, lastTrainedAt: nil)
}

struct LatestExercisePerformance: Equatable {
    var date: Date
    var sets: [SetSnapshot]
}

struct PlanWorkoutCompletionSnapshot: Equatable {
    var date: Date
    var completedPlanItemIds: Set<UUID>
    var completedHistoryKeys: Set<String>
}

struct PlanHistoryLookup: Equatable {
    var latestByPlanItemId: [UUID: LatestExercisePerformance]
    var latestByHistoryKey: [String: LatestExercisePerformance]
    var lastWorkoutByPlanId: [UUID: PlanWorkoutCompletionSnapshot]

    static let empty = PlanHistoryLookup(
        latestByPlanItemId: [:],
        latestByHistoryKey: [:],
        lastWorkoutByPlanId: [:]
    )

    func latestSets(for item: PlanItem) -> [SetSnapshot] {
        if let exact = latestByPlanItemId[item.itemId] { return exact.sets }
        return latestByHistoryKey[item.historyKey]?.sets ?? []
    }

    func latestDate(for item: PlanItem) -> Date? {
        latestByPlanItemId[item.itemId]?.date ?? latestByHistoryKey[item.historyKey]?.date
    }

    func keptDate(for item: PlanItem, planId: UUID?) -> Date? {
        guard let planId, let last = lastWorkoutByPlanId[planId] else { return nil }
        if last.completedPlanItemIds.contains(item.itemId) { return nil }
        if last.completedHistoryKeys.contains(item.historyKey) { return nil }
        return last.date
    }
}

struct WorkoutHistorySnapshot: Equatable {
    var home: HomeWorkoutSnapshot
    var calendarDays: [Date: WorkoutCalendarDaySummary]
    var exercisePRs: [String: PRSummary]
    var exerciseHistories: [String: ExerciseHistorySnapshot]
    var workoutRecords: [UUID: [PersonalRecord]]
    var bestWeightByExerciseKey: [String: Double]
    var planLookup: PlanHistoryLookup
    var planUsage: [UUID: PlanUsageSummary]
    var profile: ProfileWorkoutSnapshot

    static let empty = WorkoutHistorySnapshot(
        home: .empty,
        calendarDays: [:],
        exercisePRs: [:],
        exerciseHistories: [:],
        workoutRecords: [:],
        bestWeightByExerciseKey: [:],
        planLookup: .empty,
        planUsage: [:],
        profile: .empty
    )
}

@MainActor
@Observable
final class WorkoutHistoryStore {
    private let modelContext: ModelContext

    private var snapshot: WorkoutHistorySnapshot = .empty
    var home: HomeWorkoutSnapshot { snapshot.home }
    var calendarDays: [Date: WorkoutCalendarDaySummary] { snapshot.calendarDays }
    var exercisePRs: [String: PRSummary] { snapshot.exercisePRs }
    var exerciseHistories: [String: ExerciseHistorySnapshot] { snapshot.exerciseHistories }
    var workoutRecords: [UUID: [PersonalRecord]] { snapshot.workoutRecords }
    var bestWeightByExerciseKey: [String: Double] { snapshot.bestWeightByExerciseKey }
    var planLookup: PlanHistoryLookup { snapshot.planLookup }
    var planUsage: [UUID: PlanUsageSummary] { snapshot.planUsage }
    var profile: ProfileWorkoutSnapshot { snapshot.profile }
    var lastRefreshReason: WorkoutHistoryRefreshReason?
    var lastRefreshFinishedAt: Date?
    var isRefreshing = false

    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var hasScheduledRefresh = false
    @ObservationIgnored private var pendingRefreshReason: WorkoutHistoryRefreshReason?
    @ObservationIgnored private var dirtyGeneration = 1
    @ObservationIgnored private var lastBuiltGeneration = 0

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func scheduleRefresh(reason: WorkoutHistoryRefreshReason, delayNanoseconds: UInt64 = 500_000_000) {
        dirtyGeneration += 1
        guard !isRefreshing else {
            pendingRefreshReason = reason
            WorkoutPerformanceMonitor.event("history.refresh.coalesced")
            return
        }
        enqueueRefresh(reason: reason, delayNanoseconds: delayNanoseconds)
    }

    func ensureLoaded(reason: WorkoutHistoryRefreshReason, delayNanoseconds: UInt64 = 0) {
        guard needsRefresh else {
            WorkoutPerformanceMonitor.event("history.refresh.skipped")
            return
        }
        guard !isRefreshing, !hasScheduledRefresh else {
            WorkoutPerformanceMonitor.event("history.refresh.coalesced")
            return
        }
        enqueueRefresh(reason: reason, delayNanoseconds: delayNanoseconds)
    }

    func refresh(reason: WorkoutHistoryRefreshReason) async {
        dirtyGeneration += 1
        refreshTask?.cancel()
        hasScheduledRefresh = false
        await performRefresh(reason: reason)
    }

    private var needsRefresh: Bool {
        dirtyGeneration != lastBuiltGeneration
    }

    private func enqueueRefresh(reason: WorkoutHistoryRefreshReason, delayNanoseconds: UInt64) {
        refreshTask?.cancel()
        hasScheduledRefresh = true
        refreshTask = Task { [weak self] in
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            guard !Task.isCancelled else { return }
            await self?.runScheduledRefresh(reason: reason)
        }
    }

    private func runScheduledRefresh(reason: WorkoutHistoryRefreshReason) async {
        hasScheduledRefresh = false
        refreshTask = nil
        await performRefresh(reason: reason)
    }

    private func performRefresh(reason: WorkoutHistoryRefreshReason) async {
        guard !isRefreshing else {
            pendingRefreshReason = reason
            return
        }
        let generation = dirtyGeneration
        var didBuild = false
        isRefreshing = true

        WorkoutPerformanceMonitor.event("history.refresh.requested")
        do {
            let projection = try WorkoutPerformanceMonitor.measure("history.refresh") {
                try Self.buildProjection(modelContext: modelContext)
            }
            snapshot = WorkoutHistorySnapshot(
                home: projection.home,
                calendarDays: projection.calendarDays,
                exercisePRs: projection.exercisePRs,
                exerciseHistories: projection.exerciseHistories,
                workoutRecords: projection.workoutRecords,
                bestWeightByExerciseKey: projection.bestWeightByExerciseKey,
                planLookup: projection.planLookup,
                planUsage: projection.planUsage,
                profile: projection.profile
            )
            lastBuiltGeneration = generation
            lastRefreshReason = reason
            lastRefreshFinishedAt = .now
            logDataScaleIfNeeded(projection.scale)
            WorkoutPerformanceMonitor.event("history.refresh.completed")
            didBuild = true
        } catch {
            #if DEBUG
            print("[WorkoutHistoryStore] refresh failed: \(error)")
            #endif
        }

        isRefreshing = false
        if didBuild, dirtyGeneration != lastBuiltGeneration {
            let nextReason = pendingRefreshReason ?? reason
            pendingRefreshReason = nil
            enqueueRefresh(reason: nextReason, delayNanoseconds: 500_000_000)
        } else {
            pendingRefreshReason = nil
        }
    }

    func exerciseHistory(for key: String) -> ExerciseHistorySnapshot {
        exerciseHistories[key] ?? .empty(key)
    }

    func calendarDay(for date: Date, calendar: Calendar = .currentMondayFirst) -> WorkoutCalendarDaySummary? {
        snapshot.calendarDays[calendar.startOfDay(for: date)]
    }

    func calendarMonth(containing date: Date, calendar: Calendar = .currentMondayFirst) -> WorkoutCalendarMonthSnapshot {
        guard let monthStart = Self.monthStart(for: date, calendar: calendar) else {
            return .empty(monthStart: calendar.startOfDay(for: date))
        }
        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingDays = (weekday - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: monthStart) ?? monthStart
        let today = calendar.startOfDay(for: .now)
        let days = (0..<42).compactMap { offset -> WorkoutCalendarDayCell? in
            guard let rawDay = calendar.date(byAdding: .day, value: offset, to: gridStart) else { return nil }
            let day = calendar.startOfDay(for: rawDay)
            return WorkoutCalendarDayCell(
                date: day,
                isInDisplayedMonth: calendar.isDate(day, equalTo: monthStart, toGranularity: .month),
                isToday: calendar.isDate(day, inSameDayAs: today),
                summary: snapshot.calendarDays[day]
            )
        }
        let inMonthSummaries = days
            .filter(\.isInDisplayedMonth)
            .compactMap(\.summary)
        return WorkoutCalendarMonthSnapshot(
            monthStart: monthStart,
            days: days,
            workoutCount: inMonthSummaries.reduce(0) { $0 + $1.workoutCount },
            setCount: inMonthSummaries.reduce(0) { $0 + $1.setCount },
            volumeKg: inMonthSummaries.reduce(0) { $0 + $1.volumeKg }
        )
    }

    func calendarArchiveMonths(calendar: Calendar = .currentMondayFirst) -> [WorkoutCalendarMonthArchiveItem] {
        let monthSummaries = Dictionary(grouping: snapshot.calendarDays.values) { summary in
            Self.monthStart(for: summary.date, calendar: calendar) ?? calendar.startOfDay(for: summary.date)
        }
        let currentMonth = Self.monthStart(for: .now, calendar: calendar) ?? calendar.startOfDay(for: .now)
        let earliestMonth = monthSummaries.keys.min() ?? currentMonth

        var result: [WorkoutCalendarMonthArchiveItem] = []
        var cursor = currentMonth
        while cursor >= earliestMonth {
            let summaries = monthSummaries[cursor] ?? []
            let activeDays = Set(summaries.map { calendar.component(.day, from: $0.date) })
            result.append(WorkoutCalendarMonthArchiveItem(
                monthStart: cursor,
                trainingDayCount: summaries.count,
                workoutCount: summaries.reduce(0) { $0 + $1.workoutCount },
                setCount: summaries.reduce(0) { $0 + $1.setCount },
                volumeKg: summaries.reduce(0) { $0 + $1.volumeKg },
                activeDayNumbers: activeDays
            ))
            guard let previous = calendar.date(byAdding: .month, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return result
    }

    func calendarArchiveYearGroups(calendar: Calendar = .currentMondayFirst) -> [WorkoutCalendarYearArchiveGroup] {
        let months = calendarArchiveMonths(calendar: calendar)
        let grouped = Dictionary(grouping: months) { item in
            calendar.component(.year, from: item.monthStart)
        }
        return grouped.keys.sorted(by: >).map { year in
            WorkoutCalendarYearArchiveGroup(
                year: year,
                months: grouped[year]?.sorted { $0.monthStart > $1.monthStart } ?? []
            )
        }
    }

    private struct Projection {
        var home: HomeWorkoutSnapshot
        var calendarDays: [Date: WorkoutCalendarDaySummary]
        var exercisePRs: [String: PRSummary]
        var exerciseHistories: [String: ExerciseHistorySnapshot]
        var workoutRecords: [UUID: [PersonalRecord]]
        var bestWeightByExerciseKey: [String: Double]
        var planLookup: PlanHistoryLookup
        var planUsage: [UUID: PlanUsageSummary]
        var profile: ProfileWorkoutSnapshot
        var scale: DataScale
    }

    private struct DataScale {
        var workouts: Int
        var finished: Int
        var active: Int
        var pending: Int
        var exercises: Int
        var sets: Int
    }

    private static func buildProjection(modelContext: ModelContext) throws -> Projection {
        var descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.includePendingChanges = true
        let workouts = try modelContext.fetch(descriptor)
        let finishedDesc = workouts.filter(\.isFinished)
        let finishedAsc = finishedDesc.reversed()

        var exerciseCount = 0
        var setCount = 0
        var pendingCount = 0
        for w in workouts {
            if w.syncStatus != .synced { pendingCount += 1 }
            exerciseCount += w.exercises.count
            for ex in w.exercises { setCount += ex.sets.count }
        }

        var prByWorkoutId: [UUID: PRBadge] = [:]
        var recordsByWorkoutId: [UUID: [PersonalRecord]] = [:]
        var bestByKey: [String: Double] = [:]
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
                if let maxWeight = statEntries.compactMap(\.weightKg).max(), !seenKeys.contains(key) {
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
                    allWeightsByKey[key, default: []].append((weight, w.startedAt))
                    if let cur = exerciseBest[key] {
                        if weight > cur.weight || (weight == cur.weight && w.startedAt > cur.date) {
                            exerciseBest[key] = (weight, reps, w.startedAt)
                        }
                    } else {
                        exerciseBest[key] = (weight, reps, w.startedAt)
                    }
                }

                if let maxWeight = statEntries.compactMap(\.weightKg).max() {
                    bestByKey[key] = max(bestByKey[key] ?? maxWeight, maxWeight)
                    var point = perWorkoutPoint[key] ?? (nil, nil, nil)
                    point.maxWeight = max(point.maxWeight ?? maxWeight, maxWeight)
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

            if let first = records.first {
                prByWorkoutId[w.localId] = PRBadge(name: first.exerciseName, weightKg: first.weightKg)
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
            let prevBest = (allWeightsByKey[key] ?? [])
                .filter { !cal.isDate($0.date, inSameDayAs: best.date) }
                .map(\.weight)
                .max()
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
        let weekBounds = WorkoutWeeklyStats.weekBounds(for: now, calendar: .currentMondayFirst)
        func rowSummary(for w: Workout) -> WorkoutRowSummary {
            let duration = w.endedAt.map { $0.timeIntervalSince(w.timerStartedAt ?? w.startedAt) }
            let volume = w.exercises.flatMap(\.sets).reduce(0.0) { acc, set in
                guard set.countsForStats else { return acc }
                return acc + set.statEntries.reduce(0.0) { entryAcc, entry in
                    entryAcc + (entry.weightKg ?? 0) * Double(entry.reps ?? 0)
                }
            }
            return WorkoutRowSummary(
                id: w.localId,
                title: w.title ?? "训练",
                startedAt: w.startedAt,
                durationSec: duration,
                exerciseCount: w.exercises.count,
                setCount: w.exercises.flatMap(\.sets).filter(\.countsForStats).count,
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
            rowSummary: rowSummary
        )

        let cutoff = Date.now.addingTimeInterval(-14 * 86_400)
        let recentPlanIdsInOrder = finishedDesc
            .filter { $0.startedAt > cutoff }
            .compactMap(\.planId)
        let recentPlanIds = Set(recentPlanIdsInOrder)
        let activePlanId = recentPlanIdsInOrder.first

        let home = HomeWorkoutSnapshot(
            currentWeekStats: WorkoutWeeklyStats.compute(
                workouts: finishedDesc,
                reference: now,
                calendar: .currentMondayFirst
            ),
            weekWorkouts: Array(weekWorkouts),
            weekTrainingDays: WorkoutWeeklyStats.dayStatuses(
                workouts: finishedDesc,
                reference: now,
                calendar: .currentMondayFirst
            ),
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

        let planLookup = PlanHistoryLookup.build(from: finishedDesc)
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
            scale: scale
        )
    }

    private static func monthStart(for date: Date, calendar: Calendar) -> Date? {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps).map { calendar.startOfDay(for: $0) }
    }

    private static func buildCalendarDays(
        from workouts: [Workout],
        prByWorkoutId: [UUID: PRBadge],
        rowSummary: (Workout) -> WorkoutRowSummary,
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
                        acc + (entry.weightKg ?? 0) * Double(entry.reps ?? 0)
                    }
                }
            }
            days[day] = summary
        }
        return days
    }

    private func logDataScaleIfNeeded(_ scale: DataScale) {
        #if DEBUG
        print("[WorkoutHistoryStore] workouts=\(scale.workouts) finished=\(scale.finished) active=\(scale.active) pending=\(scale.pending) exercises=\(scale.exercises) sets=\(scale.sets)")
        #endif
    }
}

extension PlanHistoryLookup {
    static func build(from workouts: [Workout]) -> PlanHistoryLookup {
        var latestByPlanItemId: [UUID: LatestExercisePerformance] = [:]
        var latestByHistoryKey: [String: LatestExercisePerformance] = [:]
        var lastWorkoutByPlanId: [UUID: PlanWorkoutCompletionSnapshot] = [:]

        for workout in workouts {
            var completedPlanItemIds = Set<UUID>()
            var completedHistoryKeys = Set<String>()
            for ex in workout.exercises {
                let done = ex.sets
                    .filter(\.countsForStats)
                    .sorted { $0.setIndex < $1.setIndex }
                guard !done.isEmpty else { continue }
                let snapshots = done.map {
                    let summary = $0.summaryWeightReps
                    return SetSnapshot(weightKg: summary.weightKg,
                                       reps: summary.reps,
                                       setTypeRaw: $0.setTypeRaw,
                                       segments: $0.segments)
                }

                if let planItemId = ex.planItemId {
                    completedPlanItemIds.insert(planItemId)
                    if latestByPlanItemId[planItemId] == nil {
                        latestByPlanItemId[planItemId] = LatestExercisePerformance(
                            date: workout.startedAt,
                            sets: snapshots
                        )
                    }
                }

                let key = ex.historyKey
                if latestByHistoryKey[key] == nil {
                    latestByHistoryKey[key] = LatestExercisePerformance(
                        date: workout.startedAt,
                        sets: snapshots
                    )
                }
                completedHistoryKeys.insert(ex.historyKey)
            }

            if let planId = workout.planId, lastWorkoutByPlanId[planId] == nil {
                lastWorkoutByPlanId[planId] = PlanWorkoutCompletionSnapshot(
                    date: workout.startedAt,
                    completedPlanItemIds: completedPlanItemIds,
                    completedHistoryKeys: completedHistoryKeys
                )
            }
        }

        return PlanHistoryLookup(
            latestByPlanItemId: latestByPlanItemId,
            latestByHistoryKey: latestByHistoryKey,
            lastWorkoutByPlanId: lastWorkoutByPlanId
        )
    }
}
