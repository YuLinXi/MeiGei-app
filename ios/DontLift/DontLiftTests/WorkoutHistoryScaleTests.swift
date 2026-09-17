import Foundation
import SwiftData
import Testing
@testable import DontLift

@Suite(.serialized)
@MainActor
struct WorkoutHistoryScaleTests {
    @Test(arguments: [0, 10, 600, 1_000])
    func savedHistoryMatchesModelsAtScale(count: Int) async throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        var history: [Workout] = []
        for index in 0..<count {
            let startedAt = Date.now.addingTimeInterval(-Double(index + 1) * 86400)
            let exercises = (0..<6).map { exerciseIndex in
                WorkoutExercise(builtinExerciseCode: "BB_BENCH_PRESS", exerciseName: "杠铃卧推", primaryMuscle: "胸",
                                orderIndex: exerciseIndex, sets: (0..<4).map {
                    WorkoutSet(setIndex: $0, weightKg: Double(40 + index % 60), reps: 10, completed: true)
                })
            }
            let workout = Workout(startedAt: startedAt, endedAt: startedAt.addingTimeInterval(3600), exercises: exercises)
            context.insert(workout)
            history.append(workout)
        }
        try context.save()
        let expected = PRStats.maxWeightByKey(in: history)
        let store = WorkoutHistoryStore(modelContext: context)
        let start = ContinuousClock.now
        await store.refresh(reason: .manual)
        print("PERF history count=\(count) elapsed=\(start.duration(to: .now))")
        #expect(store.isCurrent)
        #expect(store.profile.totalWorkouts == count)
        #expect(store.bestWeightByExerciseKey == expected)
        #expect(store.calendarDays.values.reduce(0) { $0 + $1.setCount } == count * 24)
        let date = store.lastRefreshFinishedAt
        for _ in 0..<30 { #expect(await store.waitUntilLoaded()) }
        #expect(store.lastRefreshFinishedAt == date)
    }

    @Test func rawSnapshotsPreserveSpecialSetSemanticsAndAliases() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let first = WorkoutExercise(builtinExerciseCode: "ASSISTED_PULL_UP", exerciseName: "辅助引体向上", orderIndex: 0,
            sets: [WorkoutSet(setIndex: 0, weightKg: 20, reps: 8, completed: true),
                   WorkoutSet(setIndex: 1, weightKg: 10, reps: 12, completed: true, isWarmup: true)])
        let second = WorkoutExercise(exerciseName: "上斜杠铃卧推", orderIndex: 1,
            sets: [WorkoutSet(setIndex: 0, completed: true, setType: .drop, segments: [
                WorkoutSetSegment(segmentIndex: 1, weightKg: 30, reps: 12),
                WorkoutSetSegment(segmentIndex: 0, weightKg: 50, reps: 8)
            ])])
        let workout = Workout(startedAt: .now.addingTimeInterval(-3600), endedAt: .now, exercises: [first, second])
        workout.appendSupersetUnit(first: first, second: second, roundCount: 1)
        context.insert(workout)
        try context.save()
        let raw = try await Task.detached { try await WorkoutHistoryReader(modelContainer: container).read() }.value
        let metadata = HistoryWorkout.metadata(for: raw)
        let values = HistoryWorkout.applying(metadata, to: raw)
        let value = try #require(values.first)
        #expect(value.trainingUnits.first?.kind == .superset)
        for exercise in workout.exercises {
            let snapshot = try #require(value.exercise(id: exercise.localId))
            #expect(snapshot.historyKey == exercise.historyKey)
            #expect(snapshot.displayExerciseName == exercise.displayExerciseName)
            #expect(snapshot.assistancePerformances == exercise.assistancePerformances)
            for set in exercise.sets {
                let valueSet = try #require(snapshot.sets.first { $0.localId == set.localId })
                #expect(valueSet.statEntries == set.statEntries)
                #expect(valueSet.summaryWeightReps.weightKg == set.summaryWeightReps.weightKg)
                #expect(valueSet.summaryWeightReps.reps == set.summaryWeightReps.reps)
            }
        }
        workout.markDeleted()
        try context.save()
        let store = WorkoutHistoryStore(modelContext: context)
        await store.refresh(reason: .manual)
        #expect(store.profile.totalWorkouts == 0)
        #expect(store.planLookup == .empty)
    }
}
