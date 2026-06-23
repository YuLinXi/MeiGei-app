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
    var chartPoints: [(idx: Int, weight: Double)] {
        Array(points.suffix(120)).enumerated().compactMap { idx, point in
            point.maxWeightKg.map { (idx, $0) }
        }
    }
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
    var recent: [WorkoutRowSummary]
    var recentPlanIds: Set<UUID>
    var activePlanId: UUID?
    var prByWorkoutId: [UUID: PRBadge]

    static let empty = HomeWorkoutSnapshot(
        currentWeekStats: .empty,
        recent: [],
        recentPlanIds: [],
        activePlanId: nil,
        prByWorkoutId: [:]
    )
}

struct ProfileWorkoutSnapshot: Equatable {
    var totalWorkouts: Int
    var longestStreak: Int

    static let empty = ProfileWorkoutSnapshot(totalWorkouts: 0, longestStreak: 0)
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
    var exercisePRs: [String: PRSummary]
    var exerciseHistories: [String: ExerciseHistorySnapshot]
    var workoutRecords: [UUID: [PersonalRecord]]
    var bestWeightByExerciseKey: [String: Double]
    var planLookup: PlanHistoryLookup
    var planUsage: [UUID: PlanUsageSummary]
    var profile: ProfileWorkoutSnapshot

    static let empty = WorkoutHistorySnapshot(
        home: .empty,
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

    private struct Projection {
        var home: HomeWorkoutSnapshot
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
                if let maxWeight = counted.compactMap(\.weightKg).max(), !seenKeys.contains(key) {
                    let prior = bestByKey[key]
                    if prior == nil || maxWeight > prior! {
                        records.append(PersonalRecord(
                            exerciseName: ex.exerciseName,
                            weightKg: maxWeight,
                            previousBestKg: prior
                        ))
                        seenKeys.insert(key)
                    }
                }

                for s in counted {
                    guard let weight = s.weightKg, let reps = s.reps, reps > 0 else { continue }
                    allWeightsByKey[key, default: []].append((weight, w.startedAt))
                    if let cur = exerciseBest[key] {
                        if weight > cur.weight || (weight == cur.weight && w.startedAt > cur.date) {
                            exerciseBest[key] = (weight, reps, w.startedAt)
                        }
                    } else {
                        exerciseBest[key] = (weight, reps, w.startedAt)
                    }
                }

                if let maxWeight = counted.compactMap(\.weightKg).max() {
                    bestByKey[key] = max(bestByKey[key] ?? maxWeight, maxWeight)
                    var point = perWorkoutPoint[key] ?? (nil, nil, nil)
                    point.maxWeight = max(point.maxWeight ?? maxWeight, maxWeight)
                    perWorkoutPoint[key] = point
                } else if perWorkoutPoint[key] == nil {
                    perWorkoutPoint[key] = (nil, nil, nil)
                }

                if let last = sortedSets.last(where: { $0.weightKg != nil && $0.reps != nil }),
                   let wt = last.weightKg,
                   let reps = last.reps {
                    var point = perWorkoutPoint[key] ?? (nil, nil, nil)
                    point.lastWeight = wt
                    point.lastReps = reps
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
        let startOfToday = Calendar.current.startOfDay(for: now)
        let recentCutoff = Calendar.current.date(byAdding: .day, value: -2, to: startOfToday)
            ?? now.addingTimeInterval(-3 * 86_400)
        let recent = finishedDesc
            .filter { $0.startedAt >= recentCutoff && $0.startedAt <= now }
            .map { w in
                let duration = w.endedAt.map { $0.timeIntervalSince(w.timerStartedAt ?? w.startedAt) }
                let volume = w.exercises.flatMap(\.sets).reduce(0.0) { acc, set in
                    guard set.countsForStats else { return acc }
                    return acc + (set.weightKg ?? 0) * Double(set.reps ?? 0)
                }
                return WorkoutRowSummary(
                    id: w.localId,
                    title: w.title ?? "训练",
                    startedAt: w.startedAt,
                    durationSec: duration,
                    exerciseCount: w.exercises.count,
                    setCount: w.exercises.reduce(0) { $0 + $1.sets.count },
                    volumeKg: volume,
                    pr: prByWorkoutId[w.localId]
                )
            }

        let cutoff = Date.now.addingTimeInterval(-14 * 86_400)
        let recentPlanIdsInOrder = finishedDesc
            .filter { $0.startedAt > cutoff }
            .compactMap(\.planId)
        let recentPlanIds = Set(recentPlanIdsInOrder)
        let activePlanId = recentPlanIdsInOrder.first

        let home = HomeWorkoutSnapshot(
            currentWeekStats: WorkoutWeeklyStats.compute(workouts: finishedDesc),
            recent: Array(recent),
            recentPlanIds: recentPlanIds,
            activePlanId: activePlanId,
            prByWorkoutId: prByWorkoutId
        )

        let profile = ProfileWorkoutSnapshot(
            totalWorkouts: finishedDesc.count,
            longestStreak: longestStreak(in: finishedDesc)
        )

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

    private static func longestStreak(in workouts: [Workout]) -> Int {
        let cal = Calendar.current
        let days = Set(workouts.map { cal.startOfDay(for: $0.startedAt) })
        let sorted = days.sorted()
        var best = 0
        var current = 0
        var previous: Date?
        for day in sorted {
            if let previous, cal.date(byAdding: .day, value: 1, to: previous) == day {
                current += 1
            } else {
                current = 1
            }
            best = max(best, current)
            previous = day
        }
        return best
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
                let snapshots = done.map { SetSnapshot(weightKg: $0.weightKg, reps: $0.reps) }

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
