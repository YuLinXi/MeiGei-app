import Foundation
import SwiftData
import Testing
@testable import DontLift

@MainActor
struct WorkoutHistoryProjectionTests {

    private func makeContainer() -> ModelContainer {
        AppModelContainer.make(inMemory: true)
    }

    private func makeWorkout(
        id: UUID = UUID(),
        planId: UUID? = nil,
        startedAt: Date,
        code: String,
        name: String = "杠铃卧推",
        weights: [Double],
        planItemId: UUID? = nil
    ) -> Workout {
        let workout = Workout(
            localId: id,
            planId: planId,
            title: "训练",
            startedAt: startedAt,
            timerStartedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(3600)
        )
        let exercise = WorkoutExercise(
            builtinExerciseCode: code,
            exerciseName: name,
            primaryMuscle: "胸",
            orderIndex: 0,
            planItemId: planItemId
        )
        exercise.sets = weights.enumerated().map { idx, weight in
            WorkoutSet(setIndex: idx, weightKg: weight, reps: 5 + idx, completed: true)
        }
        workout.exercises = [exercise]
        return workout
    }

    @Test func refreshBuildsHomeProfilePRAndExerciseHistory() async throws {
        let container = makeContainer()
        let context = container.mainContext
        let planId = UUID()
        let oldId = UUID()
        let firstId = UUID()
        let secondId = UUID()
        let now = Date()
        let old = makeWorkout(
            id: oldId,
            planId: planId,
            startedAt: now.addingTimeInterval(-4 * 86_400),
            code: "BB_BENCH_PRESS",
            weights: [50]
        )
        let first = makeWorkout(
            id: firstId,
            planId: planId,
            startedAt: now.addingTimeInterval(-2 * 86_400),
            code: "BB_BENCH_PRESS",
            weights: [60, 62.5]
        )
        let second = makeWorkout(
            id: secondId,
            planId: planId,
            startedAt: now.addingTimeInterval(-86_400),
            code: "BB_BENCH_PRESS",
            weights: [65, 70]
        )
        context.insert(old)
        context.insert(first)
        context.insert(second)
        try context.save()

        let store = WorkoutHistoryStore(modelContext: context)
        await store.refresh(reason: .manual)

        #expect(store.home.recent.count == 2)
        #expect(store.home.recent.first?.id == secondId)
        #expect(!store.home.recent.contains(where: { $0.id == oldId }))
        #expect(store.profile.totalWorkouts == 3)
        #expect(store.home.recentPlanIds.contains(planId))
        #expect(store.exercisePRs["BB_BENCH_PRESS"]?.weightKg == 70)
        #expect(store.bestWeightByExerciseKey["BB_BENCH_PRESS"] == 70)
        #expect(store.exerciseHistory(for: "BB_BENCH_PRESS").points.count == 3)
        #expect(store.workoutRecords[oldId]?.first?.weightKg == 50)
        #expect(store.workoutRecords[firstId]?.first?.weightKg == 62.5)
        #expect(store.workoutRecords[secondId]?.first?.weightKg == 70)
    }

    @Test func personalRecordDetectionUsesPriorBestIndex() {
        let workout = makeWorkout(
            startedAt: Date(timeIntervalSince1970: 3_000),
            code: "BB_BENCH_PRESS",
            weights: [65, 70]
        )

        let newRecord = detectPersonalRecords(
            in: workout,
            priorBestByKey: ["BB_BENCH_PRESS": 60]
        )
        #expect(newRecord.count == 1)
        #expect(newRecord.first?.weightKg == 70)
        #expect(newRecord.first?.previousBestKg == 60)

        let noRecord = detectPersonalRecords(
            in: workout,
            priorBestByKey: ["BB_BENCH_PRESS": 80]
        )
        #expect(noRecord.isEmpty)

        let firstRecord = detectPersonalRecords(in: workout, priorBestByKey: [:])
        #expect(firstRecord.count == 1)
        #expect(firstRecord.first?.previousBestKg == nil)
    }

    @Test func planHistoryLookupUsesItemIdBeforeHistoryKey() {
        let key = "BB_BENCH_PRESS"
        let firstItemId = UUID()
        let secondItemId = UUID()
        let firstWorkout = makeWorkout(
            startedAt: Date(timeIntervalSince1970: 1_000),
            code: key,
            weights: [90],
            planItemId: firstItemId
        )
        let secondWorkout = makeWorkout(
            startedAt: Date(timeIntervalSince1970: 2_000),
            code: key,
            weights: [55],
            planItemId: secondItemId
        )

        let lookup = PlanHistoryLookup.build(from: [secondWorkout, firstWorkout])
        let secondItem = PlanItem(
            itemId: secondItemId,
            builtinExerciseCode: key,
            exerciseName: "杠铃卧推",
            orderIndex: 1,
            suggestedSets: 1,
            suggestedReps: 8,
            suggestedWeightKg: 60
        )
        let unknownItem = PlanItem(
            itemId: UUID(),
            builtinExerciseCode: key,
            exerciseName: "杠铃卧推",
            orderIndex: 2,
            suggestedSets: 1,
            suggestedReps: 8,
            suggestedWeightKg: 60
        )

        #expect(lookup.latestSets(for: secondItem).first?.weightKg == 55)
        #expect(lookup.latestSets(for: unknownItem).first?.weightKg == 55)
    }

    @Test func chartPointsAreCappedToRecent120Points() {
        let points = (0..<160).map { idx in
            ExerciseHistoryPoint(
                date: Date(timeIntervalSince1970: Double(idx)),
                maxWeightKg: Double(idx),
                lastSetWeightKg: Double(idx),
                lastSetReps: 8
            )
        }
        let snapshot = ExerciseHistorySnapshot(
            exerciseKey: "BB_BENCH_PRESS",
            points: points,
            pr: nil
        )

        #expect(snapshot.chartPoints.count == 120)
        #expect(snapshot.chartPoints.first?.weight == 40)
        #expect(snapshot.chartPoints.last?.weight == 159)
    }

    @Test func ensureLoadedSkipsCleanSnapshotAndDirtyScheduleRebuilds() async throws {
        let container = makeContainer()
        let context = container.mainContext
        let first = makeWorkout(
            startedAt: Date(timeIntervalSince1970: 1_000),
            code: "BB_BENCH_PRESS",
            weights: [60]
        )
        context.insert(first)
        try context.save()

        let store = WorkoutHistoryStore(modelContext: context)
        await store.refresh(reason: .manual)
        let firstRefreshAt = store.lastRefreshFinishedAt

        store.ensureLoaded(reason: .manual)
        try await Task.sleep(for: .milliseconds(20))
        #expect(store.lastRefreshFinishedAt == firstRefreshAt)
        #expect(store.profile.totalWorkouts == 1)

        let second = makeWorkout(
            startedAt: Date(timeIntervalSince1970: 2_000),
            code: "BB_BENCH_PRESS",
            weights: [70]
        )
        context.insert(second)
        try context.save()

        store.scheduleRefresh(reason: .workoutChanged, delayNanoseconds: 0)
        for _ in 0..<50 {
            if store.profile.totalWorkouts == 2 { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(store.profile.totalWorkouts == 2)
        #expect(store.lastRefreshFinishedAt != firstRefreshAt)
    }

    @Test func debugLoadTestDataSeedsExpectedScaleAndProjection() async throws {
        #if DEBUG
        let container = makeContainer()
        let context = container.mainContext
        let count = 1_000
        let startDate = Date.now.addingTimeInterval(-Double(count - 1) * 86_400)
        let result = try WorkoutHistoryLoadTestData.seed(count: count, in: context, startDate: startDate)

        #expect(result.workouts == count)
        #expect(result.exercises >= 4_000)
        #expect(result.sets >= 15_000)

        let store = WorkoutHistoryStore(modelContext: context)
        await store.refresh(reason: .manual)

        #expect(store.profile.totalWorkouts == count)
        #expect(store.home.recent.count == 3)
        #expect(!store.exercisePRs.isEmpty)
        #endif
    }

    @Test func debugLoadTestDataSupportsFiveThousandWorkoutProjection() async throws {
        #if DEBUG
        let container = makeContainer()
        let context = container.mainContext
        let count = 5_000
        let startDate = Date.now.addingTimeInterval(-Double(count - 1) * 86_400)
        let result = try WorkoutHistoryLoadTestData.seed(count: count, in: context, startDate: startDate)

        #expect(result.workouts == count)
        #expect(result.exercises >= 20_000)
        #expect(result.sets >= 75_000)

        let store = WorkoutHistoryStore(modelContext: context)
        await store.refresh(reason: .manual)

        #expect(store.profile.totalWorkouts == count)
        #expect(store.home.recent.count == 3)
        #expect(store.home.prByWorkoutId.count <= 5_000)
        #expect(!store.exercisePRs.isEmpty)
        #endif
    }
}
