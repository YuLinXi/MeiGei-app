import Foundation
import SwiftData
import Testing
@testable import DontLift

@Suite(.serialized) @MainActor
struct AssistedExerciseTests {
    private func workout(_ weight: Double, reps: Int = 8, date: Double = 1000, count: Int = 3) -> Workout {
        let exercise = WorkoutExercise(builtinExerciseCode: "ASSISTED_PULL_UP", exerciseName: "辅助引体向上", orderIndex: 0,
                                       sets: (0..<count).map { WorkoutSet(setIndex: $0, weightKg: weight, reps: reps, completed: true) })
        return Workout(startedAt: Date(timeIntervalSince1970: date), endedAt: Date(timeIntervalSince1970: date + 100), exercises: [exercise])
    }

    @Test func fixedCodeAndFormatting() {
        #expect(ExerciseWeightSemantics.isAssisted("ASSISTED_PULL_UP"))
        for code in ["PULL_UP", "LAT_PULLDOWN", "BAND_ASSISTED_PULL_UP", "辅助引体向上"] {
            #expect(!ExerciseWeightSemantics.isAssisted(code))
        }
        #expect(PlanItemDisplay.valueText(weightKg: 0, reps: 8, equipmentType: "器械", assisted: true) == "辅助 0 kg × 8 次")
        #expect(PlanItemDisplay.valueText(weightKg: nil, reps: 8, equipmentType: "器械", assisted: true) == "训练时填写 × 8 次")
    }

    @Test func volumePreservesCountsAndRawWeight() throws {
        let container = AppModelContainer.make(inMemory: true)
        let w = workout(20)
        container.mainContext.insert(w)
        try container.mainContext.save()
        #expect(w.completedStatVolumeKg == 0)
        let stats = WorkoutWeeklyStats.compute(workouts: [w], reference: w.startedAt)
        #expect(stats.volumeKg == 0)
        #expect(stats.setCount == 3)
        #expect(stats.repCount == 24)
        #expect(CheckinSummary(workout: w).totalVolumeKg == 0)
        #expect(w.exercises[0].sets[0].weightKg == 20)
        let regular = WorkoutExercise(builtinExerciseCode: "BB_BENCH_PRESS", exerciseName: "杠铃卧推", orderIndex: 1,
                                      sets: [WorkoutSet(setIndex: 0, weightKg: 50, reps: 10, completed: true)])
        w.exercises.append(regular)
        #expect(w.completedStatVolumeKg == 500)
        #expect(CheckinSummary(workout: w).totalVolumeKg == 500)
        #expect(WorkoutPosterData(workout: w).volumeText == "500")
        let board = MuscleLoadAggregator.load(workouts: [w], in: w.startedAt..<w.startedAt.addingTimeInterval(1000))
        #expect(board.reduce(0) { $0 + $1.volumeKg } == 500)
        #expect(WorkoutWeeklyStats.compute(workouts: [w], reference: w.startedAt).volumeKg == 500)
        let progress = BadgeEngine.calculateProgress(allFinishedWorkouts: [w], grants: [], currentWeight: nil)
        #expect(progress.first { $0.id == "tonnage_10t" }?.currentMetric == 500)
    }

    @Test func assistancePRRejectsRegressionAndDominatedResults() {
        typealias P = ExerciseWeightSemantics.Performance
        let prior = [P(weight: 30, reps: 10), P(weight: 20, reps: 8)]
        #expect(!ExerciseWeightSemantics.isAssistanceBreakthrough(P(weight: 25, reps: 8), prior: prior))
        #expect(!ExerciseWeightSemantics.isAssistanceBreakthrough(P(weight: 10, reps: 1), prior: prior))
        #expect(!ExerciseWeightSemantics.isAssistanceBreakthrough(P(weight: 20, reps: 9), prior: [P(weight: 20, reps: 8)]))
        #expect(!ExerciseWeightSemantics.isAssistanceBreakthrough(P(weight: 0, reps: 8), prior: []))
        #expect(ExerciseWeightSemantics.isAssistanceBreakthrough(P(weight: 0, reps: 8), prior: [P(weight: 20, reps: 8)]))
        for invalid in [P(weight: .nan, reps: 8), P(weight: -1, reps: 8), P(weight: 10, reps: 0)] {
            #expect(!ExerciseWeightSemantics.isAssistanceBreakthrough(invalid, prior: prior))
        }
        let old = workout(30)
        let better = workout(20, date: 2000)
        #expect(detectPersonalRecords(in: better, history: [old]).count == 1)
        #expect(BadgeEngine.detectBrokenPRCount(in: better, priorWorkouts: [old]) == 1)
        #expect(detectPersonalRecords(in: old, history: []).isEmpty)
        #expect(PRStats.maxWeightByKey(in: [old, better])["ASSISTED_PULL_UP"] == 20)
    }

    @Test func teamSummaryRoundTripsIdentityAndAcceptsOldJSON() throws {
        let summary = CheckinSummary(workout: workout(20))
        let decoded = try JSONDecoder().decode(CheckinSummary.self, from: JSONEncoder().encode(summary))
        #expect(decoded.exercises.first?.builtinExerciseCode == "ASSISTED_PULL_UP")
        let old = Data(#"{"name":"辅助引体向上","sets":[]}"#.utf8)
        let legacy = try JSONDecoder().decode(CheckinSummary.ExerciseSummary.self, from: old)
        #expect(legacy.builtinExerciseCode == nil)
    }

    @Test func dropSetsPlanAndBackgroundReaderAgree() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let w = workout(30, count: 1)
        let exercise = w.exercises[0]
        let set = exercise.sets[0]
        set.exercise = exercise
        set.setType = .drop
        set.segments = [WorkoutSetSegment(segmentIndex: 0, weightKg: 20, reps: 8),
                        WorkoutSetSegment(segmentIndex: 1, weightKg: 30, reps: 10)]
        set.syncDropSummaryFromSegments()
        #expect(set.weightKg == 20)
        #expect(set.segments.map(\.weightKg) == [20, 30])
        let item = PlanItem(itemId: UUID(), builtinExerciseCode: "ASSISTED_PULL_UP", exerciseName: "辅助引体向上", orderIndex: 0)
        exercise.planItemId = item.itemId
        container.mainContext.insert(w)
        try container.mainContext.save()
        #expect(w.completedStatVolumeKg == 0)
        #expect(WorkoutWeeklyStats.compute(workouts: [w], reference: w.startedAt).repCount == 18)
        let snapshots = try await Task.detached { try await BadgeHistoryReader(modelContainer: container).readWorkouts() }.value
        #expect(snapshots.first?.volumeKg == 0)
        let local = BadgeEngine.calculateProgress(allFinishedWorkouts: [w], grants: [], currentWeight: nil)
        #expect(local == BadgeEngine.calculateProgress(workouts: snapshots, grants: [], currentWeight: nil))
    }

    @Test func assistanceSummaryPrefersLowestWithoutChangingSets() throws {
        let container = AppModelContainer.make(inMemory: true)
        let w = workout(30, count: 2)
        w.exercises[0].sets.forEach { $0.exercise = w.exercises[0] }
        w.exercises[0].sets.first { $0.setIndex == 1 }?.weightKg = 20
        let item = PlanItem(itemId: UUID(), builtinExerciseCode: "ASSISTED_PULL_UP", exerciseName: "辅助引体向上", orderIndex: 0,
                            suggestedSets: 2, suggestedReps: 8, suggestedWeightKg: 30)
        w.exercises[0].planItemId = item.itemId
        container.mainContext.insert(w)
        try container.mainContext.save()
        let merged = PlanWriteback.merge(planItems: [item], workout: w)
        #expect(merged.newItems.first?.suggestedWeightKg == 20)
        #expect(w.exercises[0].sets.sorted { $0.setIndex < $1.setIndex }.map(\.weightKg) == [30, 20])
    }

    @Test func historyProjectionUsesAssistanceRules() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let old = workout(30)
        let better = workout(20, date: 2000)
        container.mainContext.insert(old)
        container.mainContext.insert(better)
        try container.mainContext.save()
        let store = WorkoutHistoryStore(modelContext: container.mainContext)
        await store.refresh(reason: .manual)
        #expect(store.workoutRecords[better.localId]?.count == 1)
        #expect(store.workoutRecords[old.localId]?.isEmpty != false)
        #expect(store.exerciseHistory(for: "ASSISTED_PULL_UP").pr?.weightKg == 20)
        #expect(store.exerciseHistory(for: "ASSISTED_PULL_UP").points.last?.maxWeightKg == 20)
    }

    @Test func rebuildRemovesUnreleasedIncorrectGrantsOnlyOnce() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let w = workout(100, reps: 100)
        context.insert(w)
        context.insert(BadgeGrant(badgeCode: "tonnage_10t", snapshotMetric: 30000))
        try context.save()
        await BadgeEngine.runBackfillIfNeeded(in: context, defaults: defaults)
        #expect(try context.fetch(FetchDescriptor<BadgeGrant>()).allSatisfy { $0.badgeCode != "tonnage_10t" })
        #expect(defaults.bool(forKey: "badge.assistedWeightRules.v1.local"))
        #expect(w.exercises[0].sets[0].weightKg == 100)
        // 规则完成后恢复永久授予语义，不因再次进入清空存根。
        context.insert(BadgeGrant(badgeCode: "tonnage_10t", snapshotMetric: 10000))
        try context.save()
        await BadgeEngine.runBackfillIfNeeded(in: context, defaults: defaults)
        #expect(try context.fetch(FetchDescriptor<BadgeGrant>()).contains { $0.badgeCode == "tonnage_10t" })
    }

    @Test func interruptedRebuildDoesNotPublishAndCanRetry() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        context.insert(workout(20))
        context.insert(BadgeGrant(badgeCode: "tonnage_10t", snapshotMetric: 10000))
        try context.save()
        let task = Task { @MainActor in await BadgeEngine.runBackfillIfNeeded(in: context, defaults: defaults) }
        task.cancel()
        _ = await task.value
        #expect(!defaults.bool(forKey: "badge.assistedWeightRules.v1.local"))
        #expect(try context.fetch(FetchDescriptor<BadgeGrant>()).contains { $0.badgeCode == "tonnage_10t" })
        await BadgeEngine.runBackfillIfNeeded(in: context, defaults: defaults)
        #expect(defaults.bool(forKey: "badge.assistedWeightRules.v1.local"))
        #expect(try context.fetch(FetchDescriptor<BadgeGrant>()).allSatisfy { $0.badgeCode != "tonnage_10t" })
    }
}
