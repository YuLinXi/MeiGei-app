import Foundation
import Testing
@testable import DontLift

@MainActor
struct WorkoutAdditionPrefillTests {

    private let benchKey = "BB_BENCH_PRESS"
    private let rowKey = "MACHINE_ROW"

    private func finishedWorkout(startedAt: TimeInterval) -> Workout {
        let date = Date(timeIntervalSince1970: startedAt)
        return Workout(
            title: "训练",
            startedAt: date,
            timerStartedAt: date,
            endedAt: date.addingTimeInterval(3_600)
        )
    }

    private func exercise(_ historyKey: String,
                          name: String,
                          orderIndex: Int,
                          sets: [WorkoutSet]) -> WorkoutExercise {
        WorkoutExercise(
            builtinExerciseCode: historyKey,
            exerciseName: name,
            primaryMuscle: "胸",
            orderIndex: orderIndex,
            sets: sets
        )
    }

    private func regularSet(_ index: Int,
                            weight: Double,
                            reps: Int,
                            warmup: Bool = false,
                            completed: Bool = true) -> WorkoutSet {
        WorkoutSet(
            setIndex: index,
            weightKg: weight,
            reps: reps,
            completed: completed,
            isWarmup: warmup
        )
    }

    private func dropSet(_ index: Int,
                         completed: Bool = true,
                         segments: [(Double, Int)]) -> WorkoutSet {
        WorkoutSet(
            setIndex: index,
            completed: completed,
            setType: .drop,
            segments: segments.enumerated().map { segmentIndex, value in
                WorkoutSetSegment(segmentIndex: segmentIndex, weightKg: value.0, reps: value.1)
            }
        )
    }

    @Test func normalAndDropHistoryAreKeptInSeparateIndexes() {
        let normalWorkout = finishedWorkout(startedAt: 1_000)
        let normalExercise = exercise(
            benchKey,
            name: "杠铃卧推",
            orderIndex: 0,
            sets: [
                regularSet(0, weight: 20, reps: 12, warmup: true),
                regularSet(1, weight: 60, reps: 8),
                regularSet(2, weight: 62.5, reps: 6)
            ]
        )
        normalWorkout.exercises = [normalExercise]
        normalWorkout.appendSingleExerciseUnit(for: normalExercise)

        let dropWorkout = finishedWorkout(startedAt: 2_000)
        let dropExercise = exercise(
            benchKey,
            name: "杠铃卧推",
            orderIndex: 0,
            sets: [dropSet(0, segments: [(55, 8), (45, 10)])]
        )
        dropWorkout.exercises = [dropExercise]
        dropWorkout.appendDropSetUnit(for: dropExercise)

        let lookup = PlanHistoryLookup.build(from: [dropWorkout, normalWorkout])
        let regular = lookup.latestSets(forWorkoutHistoryKey: benchKey, kind: .singleExercise)
        let drop = lookup.latestSets(forWorkoutHistoryKey: benchKey, kind: .dropSet)

        #expect(regular.map(\.weightKg) == [20, 60, 62.5])
        #expect(regular.map(\.isWarmup) == [true, false, false])
        #expect(drop.count == 1)
        #expect(drop.first?.segments.map(\.weightKg) == [55, 45])

        let prefills = PlanPrefill.sets(from: regular)
        #expect(prefills.allSatisfy { !$0.completed })
        #expect(prefills.map(\.isWarmup) == [true, false, false])
    }

    @Test func regularHistorySkipsWarmupOnlyAndUnfinishedSets() {
        let active = Workout(title: "进行中训练")
        let activeExercise = exercise(
            benchKey,
            name: "杠铃卧推",
            orderIndex: 0,
            sets: [regularSet(0, weight: 100, reps: 1)]
        )
        active.exercises = [activeExercise]
        active.appendSingleExerciseUnit(for: activeExercise)

        let warmupOnly = finishedWorkout(startedAt: 3_000)
        let warmupExercise = exercise(
            benchKey,
            name: "杠铃卧推",
            orderIndex: 0,
            sets: [regularSet(0, weight: 20, reps: 12, warmup: true)]
        )
        warmupOnly.exercises = [warmupExercise]
        warmupOnly.appendSingleExerciseUnit(for: warmupExercise)

        let unfinished = finishedWorkout(startedAt: 2_000)
        let unfinishedExercise = exercise(
            benchKey,
            name: "杠铃卧推",
            orderIndex: 0,
            sets: [regularSet(0, weight: 80, reps: 5, completed: false)]
        )
        unfinished.exercises = [unfinishedExercise]
        unfinished.appendSingleExerciseUnit(for: unfinishedExercise)

        let valid = finishedWorkout(startedAt: 1_000)
        let validExercise = exercise(
            benchKey,
            name: "杠铃卧推",
            orderIndex: 0,
            sets: [regularSet(0, weight: 60, reps: 8)]
        )
        valid.exercises = [validExercise]
        valid.appendSingleExerciseUnit(for: validExercise)

        let deleted = finishedWorkout(startedAt: 4_000)
        let deletedExercise = exercise(
            benchKey,
            name: "杠铃卧推",
            orderIndex: 0,
            sets: [regularSet(0, weight: 120, reps: 1)]
        )
        deleted.exercises = [deletedExercise]
        deleted.appendSingleExerciseUnit(for: deletedExercise)
        deleted.deletedAt = Date(timeIntervalSince1970: 5_000)

        let lookup = PlanHistoryLookup.build(from: [deleted, warmupOnly, unfinished, active, valid])
        #expect(lookup.latestSets(forWorkoutHistoryKey: benchKey, kind: .singleExercise).map(\.weightKg) == [60])
    }

    @Test func canonicalAliasMatchesButDifferentExercisesDoNot() {
        let legacyKey = ExerciseLibrary.canonicalHistoryKey(
            code: "REVERSE_PEC_DECK",
            name: "反向蝴蝶机",
            customId: nil
        )
        let canonicalKey = ExerciseLibrary.canonicalHistoryKey(
            code: "MACHINE_REVERSE_FLY",
            name: "蝴蝶机反向飞鸟",
            customId: nil
        )
        #expect(legacyKey == canonicalKey)

        let workout = finishedWorkout(startedAt: 1_000)
        let legacyExercise = exercise(
            "REVERSE_PEC_DECK",
            name: "反向蝴蝶机",
            orderIndex: 0,
            sets: [regularSet(0, weight: 40, reps: 10)]
        )
        workout.exercises = [legacyExercise]
        workout.appendSingleExerciseUnit(for: legacyExercise)

        let lookup = PlanHistoryLookup.build(from: [workout])
        #expect(lookup.latestSets(forWorkoutHistoryKey: canonicalKey, kind: .singleExercise).map(\.weightKg) == [40])
        #expect(lookup.latestSets(forWorkoutHistoryKey: benchKey, kind: .singleExercise).isEmpty)
    }

    @Test func supersetPairMatchesReverseAndExcludesPartialOrWarmupRounds() {
        let complete = finishedWorkout(startedAt: 1_000)
        let bench = exercise(
            benchKey,
            name: "杠铃卧推",
            orderIndex: 0,
            sets: [regularSet(0, weight: 60, reps: 10), regularSet(1, weight: 65, reps: 8)]
        )
        let row = exercise(
            rowKey,
            name: "器械划船",
            orderIndex: 1,
            sets: [regularSet(0, weight: 50, reps: 12), regularSet(1, weight: 55, reps: 10)]
        )
        complete.exercises = [bench, row]
        complete.appendSupersetUnit(first: bench, second: row, roundCount: 2)

        let invalidNewer = finishedWorkout(startedAt: 2_000)
        let partialBench = exercise(
            benchKey,
            name: "杠铃卧推",
            orderIndex: 0,
            sets: [regularSet(0, weight: 100, reps: 1, warmup: true)]
        )
        let partialRow = exercise(
            rowKey,
            name: "器械划船",
            orderIndex: 1,
            sets: [regularSet(0, weight: 100, reps: 1)]
        )
        invalidNewer.exercises = [partialBench, partialRow]
        invalidNewer.appendSupersetUnit(first: partialBench, second: partialRow, roundCount: 1)

        let lookup = PlanHistoryLookup.build(from: [invalidNewer, complete])
        let reversePair = lookup.latestSuperset(firstHistoryKey: rowKey, secondHistoryKey: benchKey)

        #expect(reversePair?.roundCount == 2)
        #expect(reversePair?.value(for: benchKey)?.weightKg == 65)
        #expect(reversePair?.value(for: rowKey)?.reps == 10)
        #expect(lookup.latestSupersetMember(forHistoryKey: benchKey)?.weightKg == 65)
    }
}
