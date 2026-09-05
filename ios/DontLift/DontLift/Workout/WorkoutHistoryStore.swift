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
    var isAssistedWeight: Bool = false
}

struct SetSnapshot: Codable, Equatable, Hashable {
    var weightKg: Double?
    var reps: Int?
    var setTypeRaw: String = WorkoutSetType.working.rawValue
    var isWarmup: Bool = false
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
    var todayCompletedWorkoutCount: Int
    var currentTrainingStreakDays: Int
    var recentPlanIds: Set<UUID>
    var activePlanId: UUID?
    var prByWorkoutId: [UUID: PRBadge]

    static let empty = HomeWorkoutSnapshot(
        currentWeekStats: .empty,
        weekWorkouts: [],
        weekTrainingDays: WorkoutWeeklyStats.dayStatuses(workouts: [], reference: .now, calendar: .currentMondayFirst),
        todayCompletedWorkoutCount: 0,
        currentTrainingStreakDays: 0,
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

    func matches(_ item: PlanItem) -> Bool {
        matches(isDropSet: item.isDropSet)
    }

    func matches(isDropSet: Bool) -> Bool {
        sets.contains { $0.setTypeRaw == WorkoutSetType.drop.rawValue } == isDropSet
    }
}

struct PlanExerciseHistoryKey: Equatable, Hashable {
    var planItemId: UUID
    var historyKey: String
}

struct PlanWorkoutCompletionSnapshot: Equatable {
    var date: Date
    var completedPlanItemIds: Set<UUID>
    var completedHistoryKeys: Set<String>
}

/// 训练中临时创建单元的历史索引键。计划预填沿用既有 planItemId 索引，避免混淆两套语义。
struct WorkoutUnitHistoryKey: Hashable {
    var historyKey: String
    var kind: WorkoutUnitKind
}

/// 超级组配对忽略选择顺序；成员值仍按各自动作 key 回填。
struct SupersetHistoryPairKey: Hashable {
    var firstHistoryKey: String
    var secondHistoryKey: String

    init(_ firstHistoryKey: String, _ secondHistoryKey: String) {
        if firstHistoryKey <= secondHistoryKey {
            self.firstHistoryKey = firstHistoryKey
            self.secondHistoryKey = secondHistoryKey
        } else {
            self.firstHistoryKey = secondHistoryKey
            self.secondHistoryKey = firstHistoryKey
        }
    }
}

struct SupersetHistoryPrefill: Equatable {
    var roundCount: Int
    var memberValues: [String: SetSnapshot]

    func value(for historyKey: String) -> SetSnapshot? {
        memberValues[historyKey]
    }
}

struct PlanHistoryLookup: Equatable {
    var latestByPlanExercise: [PlanExerciseHistoryKey: LatestExercisePerformance]
    var latestByHistoryKey: [String: LatestExercisePerformance]
    var lastWorkoutByPlanId: [UUID: PlanWorkoutCompletionSnapshot]
    /// 仅供训练中临时新增单元使用；按一级训练单元类型隔离历史。
    var latestByWorkoutUnit: [WorkoutUnitHistoryKey: LatestExercisePerformance] = [:]
    var latestSupersetMemberByHistoryKey: [String: LatestExercisePerformance] = [:]
    var latestSupersetByPair: [SupersetHistoryPairKey: SupersetHistoryPrefill] = [:]

    static let empty = PlanHistoryLookup(
        latestByPlanExercise: [:],
        latestByHistoryKey: [:],
        lastWorkoutByPlanId: [:]
    )

    func latestSets(for item: PlanItem) -> [SetSnapshot] {
        let key = PlanExerciseHistoryKey(planItemId: item.itemId, historyKey: item.historyKey)
        if let exact = latestByPlanExercise[key], exact.matches(item) { return exact.sets }
        if let fallback = latestByHistoryKey[item.historyKey], fallback.matches(item) { return fallback.sets }
        return []
    }

    /// 备选动作只读取同一动作位下该实际动作的历史，不借用其他动作位的全局同动作数据。
    func latestSets(planItemId: UUID, historyKey: String, isDropSet: Bool = false) -> [SetSnapshot] {
        let key = PlanExerciseHistoryKey(planItemId: planItemId, historyKey: historyKey)
        guard let exact = latestByPlanExercise[key], exact.matches(isDropSet: isDropSet) else { return [] }
        return exact.sets
    }

    func latestDate(for item: PlanItem) -> Date? {
        let key = PlanExerciseHistoryKey(planItemId: item.itemId, historyKey: item.historyKey)
        if let exact = latestByPlanExercise[key], exact.matches(item) { return exact.date }
        if let fallback = latestByHistoryKey[item.historyKey], fallback.matches(item) { return fallback.date }
        return nil
    }

    func keptDate(for item: PlanItem, planId: UUID?) -> Date? {
        guard let planId, let last = lastWorkoutByPlanId[planId] else { return nil }
        if last.completedPlanItemIds.contains(item.itemId) { return nil }
        if last.completedHistoryKeys.contains(item.historyKey) { return nil }
        return last.date
    }

    func latestSets(forWorkoutHistoryKey historyKey: String, kind: WorkoutUnitKind) -> [SetSnapshot] {
        latestByWorkoutUnit[WorkoutUnitHistoryKey(historyKey: historyKey, kind: kind)]?.sets ?? []
    }

    func latestSupersetMember(forHistoryKey historyKey: String) -> SetSnapshot? {
        latestSupersetMemberByHistoryKey[historyKey]?.sets.last
    }

    func latestSuperset(firstHistoryKey: String, secondHistoryKey: String) -> SupersetHistoryPrefill? {
        latestSupersetByPair[SupersetHistoryPairKey(firstHistoryKey, secondHistoryKey)]
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
    var muscleLoad: MuscleLoadSnapshot

    static let empty = WorkoutHistorySnapshot(
        home: .empty,
        calendarDays: [:],
        exercisePRs: [:],
        exerciseHistories: [:],
        workoutRecords: [:],
        bestWeightByExerciseKey: [:],
        planLookup: .empty,
        planUsage: [:],
        profile: .empty,
        muscleLoad: .empty
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
    /// 肌群周负荷快照（本周/上周看板、同期基准、近 4 周趋势与贡献明细）。
    var muscleLoad: MuscleLoadSnapshot { snapshot.muscleLoad }
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
                profile: projection.profile,
                muscleLoad: projection.muscleLoad
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
        var muscleLoad: MuscleLoadSnapshot
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
        func rowSummary(for w: Workout) -> WorkoutRowSummary {
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
                workouts: finishedDesc,
                reference: now,
                calendar: calendar
            ),
            weekWorkouts: Array(weekWorkouts),
            weekTrainingDays: WorkoutWeeklyStats.dayStatuses(
                workouts: finishedDesc,
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

        let planLookup = PlanHistoryLookup.build(from: finishedDesc)
        let muscleLoad = MuscleLoadAggregator.snapshot(workouts: finishedDesc,
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
                        acc + entry.volumeKg
                    }
                }
            }
            days[day] = summary
        }
        return days
    }

    private static func currentTrainingStreakDays(
        in workouts: [Workout],
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

    private func logDataScaleIfNeeded(_ scale: DataScale) {
        #if DEBUG
        print("[WorkoutHistoryStore] workouts=\(scale.workouts) finished=\(scale.finished) active=\(scale.active) pending=\(scale.pending) exercises=\(scale.exercises) sets=\(scale.sets)")
        #endif
    }
}

extension PlanHistoryLookup {
    static func build(from workouts: [Workout]) -> PlanHistoryLookup {
        var latestByPlanExercise: [PlanExerciseHistoryKey: LatestExercisePerformance] = [:]
        var latestByHistoryKey: [String: LatestExercisePerformance] = [:]
        var lastWorkoutByPlanId: [UUID: PlanWorkoutCompletionSnapshot] = [:]
        var latestByWorkoutUnit: [WorkoutUnitHistoryKey: LatestExercisePerformance] = [:]
        var latestSupersetMemberByHistoryKey: [String: LatestExercisePerformance] = [:]
        var latestSupersetByPair: [SupersetHistoryPairKey: SupersetHistoryPrefill] = [:]

        for workout in workouts {
            var completedPlanItemIds = Set<UUID>()
            var completedHistoryKeys = Set<String>()
            for ex in workout.exercises {
                let done = completedExecutionSets(from: ex)
                guard !done.isEmpty else { continue }
                let snapshots = done.map(PlanPrefill.snapshot(from:))

                if let planItemId = ex.planItemId {
                    completedPlanItemIds.insert(planItemId)
                    let planExerciseKey = PlanExerciseHistoryKey(planItemId: planItemId,
                                                                 historyKey: ex.historyKey)
                    if latestByPlanExercise[planExerciseKey] == nil {
                        latestByPlanExercise[planExerciseKey] = LatestExercisePerformance(
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

            if workout.isFinished {
                for unit in workout.trainingUnits {
                switch unit.kind {
                case .singleExercise, .dropSet:
                    guard let exerciseId = unit.singleExerciseId,
                          let exercise = workout.exercise(id: exerciseId) else { continue }
                    let completed = unit.kind == .singleExercise
                        ? completedRegularSets(from: exercise)
                        : completedDropSets(from: exercise)
                    guard !completed.isEmpty else { continue }
                    let key = WorkoutUnitHistoryKey(historyKey: exercise.historyKey, kind: unit.kind)
                    if latestByWorkoutUnit[key] == nil {
                        latestByWorkoutUnit[key] = LatestExercisePerformance(
                            date: workout.startedAt,
                            sets: completed.map(snapshot(from:))
                        )
                    }
                case .superset:
                    guard let superset = unit.superset,
                          superset.members.count == 2,
                          let first = workout.exercise(id: superset.members[0].exerciseId),
                          let second = workout.exercise(id: superset.members[1].exerciseId) else { continue }
                    let rounds = completedSupersetRounds(first: first, second: second, roundCount: superset.roundCount)
                    guard !rounds.isEmpty else { continue }
                    let firstKey = first.historyKey
                    let secondKey = second.historyKey
                    guard firstKey != secondKey else { continue }
                    let firstSnapshot = snapshot(from: rounds.last!.first)
                    let secondSnapshot = snapshot(from: rounds.last!.second)

                    if latestSupersetMemberByHistoryKey[firstKey] == nil {
                        latestSupersetMemberByHistoryKey[firstKey] = LatestExercisePerformance(
                            date: workout.startedAt,
                            sets: [firstSnapshot]
                        )
                    }
                    if latestSupersetMemberByHistoryKey[secondKey] == nil {
                        latestSupersetMemberByHistoryKey[secondKey] = LatestExercisePerformance(
                            date: workout.startedAt,
                            sets: [secondSnapshot]
                        )
                    }

                    let pairKey = SupersetHistoryPairKey(firstKey, secondKey)
                    if latestSupersetByPair[pairKey] == nil {
                        latestSupersetByPair[pairKey] = SupersetHistoryPrefill(
                            roundCount: rounds.count,
                            memberValues: [firstKey: firstSnapshot, secondKey: secondSnapshot]
                        )
                    }
                }
            }
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
            latestByPlanExercise: latestByPlanExercise,
            latestByHistoryKey: latestByHistoryKey,
            lastWorkoutByPlanId: lastWorkoutByPlanId,
            latestByWorkoutUnit: latestByWorkoutUnit,
            latestSupersetMemberByHistoryKey: latestSupersetMemberByHistoryKey,
            latestSupersetByPair: latestSupersetByPair
        )
    }

    private static func completedRegularSets(from exercise: WorkoutExercise) -> [WorkoutSet] {
        let regular = exercise.sets
            .filter { $0.completed && !$0.isDropSet }
            .sorted {
                if $0.isWarmupEffective != $1.isWarmupEffective {
                    return $0.isWarmupEffective && !$1.isWarmupEffective
                }
                return $0.setIndex < $1.setIndex
            }
        return regular.contains(where: { !$0.isWarmupEffective }) ? regular : []
    }

    private static func snapshot(from set: WorkoutSet) -> SetSnapshot {
        let summary = set.summaryWeightReps
        return SetSnapshot(
            weightKg: summary.weightKg,
            reps: summary.reps,
            setTypeRaw: set.setTypeRaw,
            isWarmup: set.isWarmupEffective,
            segments: set.segments
        )
    }

    private static func completedDropSets(from exercise: WorkoutExercise) -> [WorkoutSet] {
        exercise.sets
            .filter { $0.completed && $0.isDropSet && !$0.isWarmupEffective && !$0.effectiveSegments.isEmpty }
            .sorted { $0.setIndex < $1.setIndex }
    }

    private static func completedSupersetRounds(first: WorkoutExercise,
                                                second: WorkoutExercise,
                                                roundCount: Int) -> [(first: WorkoutSet, second: WorkoutSet)] {
        let firstByIndex = Dictionary(uniqueKeysWithValues: first.sets.map { ($0.setIndex, $0) })
        let secondByIndex = Dictionary(uniqueKeysWithValues: second.sets.map { ($0.setIndex, $0) })
        return (0..<max(1, roundCount)).compactMap { index in
            guard let firstSet = firstByIndex[index],
                  let secondSet = secondByIndex[index],
                  firstSet.completed,
                  secondSet.completed,
                  !firstSet.isWarmupEffective,
                  !secondSet.isWarmupEffective else { return nil }
            return (firstSet, secondSet)
        }
    }

    private static func completedExecutionSets(from exercise: WorkoutExercise) -> [WorkoutSet] {
        let completed = exercise.sets.filter(\.completed)
        let dropSets = completed
            .filter { $0.isDropSet && !$0.isWarmupEffective }
            .sorted { $0.setIndex < $1.setIndex }
        if !dropSets.isEmpty { return dropSets }
        let regular = completed
            .filter { !$0.isDropSet }
            .sorted {
                if $0.isWarmupEffective != $1.isWarmupEffective {
                    return $0.isWarmupEffective && !$1.isWarmupEffective
                }
                return $0.setIndex < $1.setIndex
            }
        guard regular.contains(where: { !$0.isWarmupEffective }) else { return [] }
        return regular
    }
}
