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

nonisolated struct PRBadge: Equatable, Hashable, Sendable {
    var name: String
    var weightKg: Double
    var isAssistedWeight: Bool = false
}

nonisolated struct SetSnapshot: Codable, Equatable, Hashable, Sendable {
    var weightKg: Double?
    var reps: Int?
    var setTypeRaw: String = WorkoutSetType.working.rawValue
    var isWarmup: Bool = false
    var segments: [WorkoutSetSegment] = []
}

nonisolated struct ExerciseHistoryPoint: Equatable, Hashable, Sendable {
    var date: Date
    var maxWeightKg: Double?
    var lastSetWeightKg: Double?
    var lastSetReps: Int?
}

nonisolated struct ExerciseHistorySnapshot: Equatable, Sendable {
    var exerciseKey: String
    var points: [ExerciseHistoryPoint]
    var pr: PRSummary?

    static func empty(_ key: String) -> ExerciseHistorySnapshot {
        ExerciseHistorySnapshot(exerciseKey: key, points: [], pr: nil)
    }

    var isEmpty: Bool { points.isEmpty }
    var last: ExerciseHistoryPoint? { points.last }
}

nonisolated struct WorkoutRowSummary: Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var title: String
    var startedAt: Date
    var durationSec: TimeInterval?
    var exerciseCount: Int
    var setCount: Int
    var volumeKg: Double
    var pr: PRBadge?
}

nonisolated struct HomeWorkoutSnapshot: Equatable, Sendable {
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
        weekTrainingDays: WorkoutWeeklyStats.dayStatuses(values: [], reference: .now, calendar: .currentMondayFirst),
        todayCompletedWorkoutCount: 0,
        currentTrainingStreakDays: 0,
        recentPlanIds: [],
        activePlanId: nil,
        prByWorkoutId: [:]
    )
}

nonisolated struct WorkoutCalendarDaySummary: Identifiable, Equatable, Hashable, Sendable {
    var date: Date
    var workouts: [WorkoutRowSummary]
    var setCount: Int
    var volumeKg: Double
    var hasPR: Bool

    var id: Date { date }
    var workoutCount: Int { workouts.count }
}

nonisolated struct WorkoutCalendarDayCell: Identifiable, Equatable, Hashable, Sendable {
    var date: Date
    var isInDisplayedMonth: Bool
    var isToday: Bool
    var summary: WorkoutCalendarDaySummary?

    var id: Date { date }
}

nonisolated struct WorkoutCalendarMonthSnapshot: Equatable, Sendable {
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

nonisolated struct WorkoutCalendarMonthArchiveItem: Identifiable, Equatable, Hashable, Sendable {
    var monthStart: Date
    var trainingDayCount: Int
    var workoutCount: Int
    var setCount: Int
    var volumeKg: Double
    var activeDayNumbers: Set<Int>

    var id: Date { monthStart }
}

nonisolated struct WorkoutCalendarYearArchiveGroup: Identifiable, Equatable, Hashable, Sendable {
    var year: Int
    var months: [WorkoutCalendarMonthArchiveItem]

    var id: Int { year }
}

nonisolated struct ProfileWorkoutSnapshot: Equatable, Sendable {
    var totalWorkouts: Int

    static let empty = ProfileWorkoutSnapshot(totalWorkouts: 0)
}

nonisolated struct PlanUsageSummary: Equatable, Hashable, Sendable {
    var completedCount: Int
    var lastTrainedAt: Date?

    static let empty = PlanUsageSummary(completedCount: 0, lastTrainedAt: nil)
}

nonisolated struct LatestExercisePerformance: Equatable, Sendable {
    var date: Date
    var sets: [SetSnapshot]

    @MainActor func matches(_ item: PlanItem) -> Bool {
        matches(isDropSet: item.isDropSet)
    }

    func matches(isDropSet: Bool) -> Bool {
        sets.contains { $0.setTypeRaw == WorkoutSetType.drop.rawValue } == isDropSet
    }
}

nonisolated struct PlanExerciseHistoryKey: Equatable, Hashable, Sendable {
    var planItemId: UUID
    var historyKey: String
}

nonisolated struct PlanWorkoutCompletionSnapshot: Equatable, Sendable {
    var date: Date
    var completedPlanItemIds: Set<UUID>
    var completedHistoryKeys: Set<String>
}

/// 训练中临时创建单元的历史索引键。计划预填沿用既有 planItemId 索引，避免混淆两套语义。
nonisolated struct WorkoutUnitHistoryKey: Hashable, Sendable {
    var historyKey: String
    var kind: WorkoutUnitKind
}

/// 超级组配对忽略选择顺序；成员值仍按各自动作 key 回填。
nonisolated struct SupersetHistoryPairKey: Hashable, Sendable {
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

nonisolated struct SupersetHistoryPrefill: Equatable, Sendable {
    var roundCount: Int
    var memberValues: [String: SetSnapshot]

    func value(for historyKey: String) -> SetSnapshot? {
        memberValues[historyKey]
    }
}

nonisolated struct PlanHistoryLookup: Equatable, Sendable {
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

    @MainActor func latestSets(for item: PlanItem) -> [SetSnapshot] {
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

    @MainActor func latestDate(for item: PlanItem) -> Date? {
        let key = PlanExerciseHistoryKey(planItemId: item.itemId, historyKey: item.historyKey)
        if let exact = latestByPlanExercise[key], exact.matches(item) { return exact.date }
        if let fallback = latestByHistoryKey[item.historyKey], fallback.matches(item) { return fallback.date }
        return nil
    }

    @MainActor func keptDate(for item: PlanItem, planId: UUID?) -> Date? {
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

nonisolated struct WorkoutHistorySnapshot: Equatable, Sendable {
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
    enum LoadState: Equatable { case notReady, refreshing, available, failed }
    private(set) var loadState: LoadState = .notReady
    var isRefreshing: Bool { loadState == .refreshing }
    var sessionRevision: Int { sessionGeneration }
    var isCurrent: Bool { hasSnapshot && dirtyGeneration == lastBuiltGeneration }
    var hasSnapshot: Bool { lastRefreshFinishedAt != nil }
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var dirtyGeneration = 1
    @ObservationIgnored private var lastBuiltGeneration = 0
    @ObservationIgnored private var sessionGeneration = 0
    @ObservationIgnored private let readHistory: @Sendable (ModelContainer) async throws -> [HistoryWorkout]

    init(modelContext: ModelContext,
         readHistory: @escaping @Sendable (ModelContainer) async throws -> [HistoryWorkout] = { container in
             try await Task.detached(priority: .userInitiated) {
                 try WorkoutHistoryReader(modelContainer: container).read()
             }.value
         }) {
        self.modelContext = modelContext
        self.readHistory = readHistory
    }

    func reset() {
        sessionGeneration += 1
        refreshTask?.cancel()
        refreshTask = nil
        dirtyGeneration += 1
        lastBuiltGeneration = 0
        snapshot = .empty
        lastRefreshReason = nil
        lastRefreshFinishedAt = nil
        loadState = .notReady
    }

    func scheduleRefresh(reason: WorkoutHistoryRefreshReason, delayNanoseconds: UInt64 = 500_000_000) {
        dirtyGeneration += 1
        ensureLoaded(reason: reason, delayNanoseconds: delayNanoseconds)
    }

    func ensureLoaded(reason: WorkoutHistoryRefreshReason, delayNanoseconds: UInt64 = 0) {
        guard dirtyGeneration != lastBuiltGeneration, refreshTask == nil else { return }
        let session = sessionGeneration
        loadState = .refreshing
        refreshTask = Task { [weak self] in
            if delayNanoseconds > 0 { try? await Task.sleep(nanoseconds: delayNanoseconds) }
            guard let self, !Task.isCancelled else { return }
            await self.performRefresh(reason: reason, session: session)
        }
    }

    func refresh(reason: WorkoutHistoryRefreshReason) async {
        scheduleRefresh(reason: reason, delayNanoseconds: 0)
        _ = await waitUntilLoaded()
    }

    /// 等待当前有效代数；失败不会把空快照当作没有历史。
    @discardableResult
    func waitUntilLoaded() async -> Bool {
        let session = sessionGeneration
        ensureLoaded(reason: .manual)
        while let task = refreshTask {
            await task.value
            guard !Task.isCancelled, session == sessionGeneration else { return false }
        }
        return hasSnapshot && dirtyGeneration == lastBuiltGeneration
    }

    private func performRefresh(reason: WorkoutHistoryRefreshReason, session: Int) async {
        while !Task.isCancelled, session == sessionGeneration {
            let generation = dirtyGeneration
            do {
                let values = try await readHistory(modelContext.container)
                try Task.checkCancellation()
                guard session == sessionGeneration else { return }
                let identities = await Task.detached(priority: .userInitiated) {
                    Set(values.flatMap { $0.exercises.map(\.identity) })
                }.value
                let metadata = Dictionary(uniqueKeysWithValues: identities.map { ($0, HistoryExerciseMetadata.resolve($0)) })
                let projection = await Task.detached(priority: .userInitiated) {
                    assert(!Thread.isMainThread)
                    return WorkoutPerformanceMonitor.measure("history.project.values") {
                        WorkoutHistoryProjection.build(workouts: HistoryWorkout.applying(metadata, to: values))
                    }
                }.value
                try Task.checkCancellation()
                guard session == sessionGeneration else { return }
                guard generation == dirtyGeneration else { continue }
                snapshot = WorkoutHistorySnapshot(
                    home: projection.home, calendarDays: projection.calendarDays,
                    exercisePRs: projection.exercisePRs, exerciseHistories: projection.exerciseHistories,
                    workoutRecords: projection.workoutRecords, bestWeightByExerciseKey: projection.bestWeightByExerciseKey,
                    planLookup: projection.planLookup, planUsage: projection.planUsage,
                    profile: projection.profile, muscleLoad: projection.muscleLoad)
                lastBuiltGeneration = generation
                lastRefreshReason = reason
                lastRefreshFinishedAt = .now
                loadState = .available
                logDataScaleIfNeeded(projection.scale)
                WorkoutPerformanceMonitor.event("history.refresh.completed")
            } catch {
                guard session == sessionGeneration else { return }
                if generation != dirtyGeneration, !Task.isCancelled { continue }
                loadState = .failed
            }
            break
        }
        guard session == sessionGeneration else { return }
        refreshTask = nil
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

    private static func monthStart(for date: Date, calendar: Calendar) -> Date? {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps).map { calendar.startOfDay(for: $0) }
    }

    private func logDataScaleIfNeeded(_ scale: WorkoutHistoryProjection.DataScale) {
        #if DEBUG
        print("[WorkoutHistoryStore] workouts=\(scale.workouts) finished=\(scale.finished) active=\(scale.active) pending=\(scale.pending) exercises=\(scale.exercises) sets=\(scale.sets)")
        #endif
    }
}

extension PlanHistoryLookup {
    @MainActor static func build(from workouts: [Workout]) -> PlanHistoryLookup {
        build(values: HistoryWorkout.resolved(workouts))
    }

    nonisolated static func build(values workouts: [HistoryWorkout]) -> PlanHistoryLookup {
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
                let snapshots = done.map(snapshot(from:))

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

    nonisolated private static func completedRegularSets(from exercise: HistoryExercise) -> [HistorySet] {
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

    nonisolated private static func snapshot(from set: HistorySet) -> SetSnapshot {
        let summary = set.summaryWeightReps
        return SetSnapshot(
            weightKg: summary.weightKg,
            reps: summary.reps,
            setTypeRaw: set.setTypeRaw,
            isWarmup: set.isWarmupEffective,
            segments: set.segments
        )
    }

    nonisolated private static func completedDropSets(from exercise: HistoryExercise) -> [HistorySet] {
        exercise.sets
            .filter { $0.completed && $0.isDropSet && !$0.isWarmupEffective && !$0.effectiveSegments.isEmpty }
            .sorted { $0.setIndex < $1.setIndex }
    }

    nonisolated private static func completedSupersetRounds(first: HistoryExercise,
                                                second: HistoryExercise,
                                                roundCount: Int) -> [(first: HistorySet, second: HistorySet)] {
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

    nonisolated private static func completedExecutionSets(from exercise: HistoryExercise) -> [HistorySet] {
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
