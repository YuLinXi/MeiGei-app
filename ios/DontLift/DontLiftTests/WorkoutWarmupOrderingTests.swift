import Testing
@testable import DontLift

@MainActor
struct WorkoutWarmupOrderingTests {

    @Test func cancelingWarmupPreservesStableOrderAndEntersOriginalWorkingPosition() {
        let exercise = WorkoutExercise(exerciseName: "杠铃卧推", orderIndex: 0)
        let firstWarmup = WorkoutSet(setIndex: 0, weightKg: 20, reps: 10, setType: .warmup)
        let secondWarmup = WorkoutSet(setIndex: 1, weightKg: 40, reps: 5, setType: .warmup)
        let firstWorking = WorkoutSet(setIndex: 2, weightKg: 60, reps: 8)
        let secondWorking = WorkoutSet(setIndex: 3, weightKg: 60, reps: 8)
        exercise.sets = [firstWarmup, secondWarmup, firstWorking, secondWorking]

        exercise.toggleWarmup(secondWarmup)

        #expect(!secondWarmup.isWarmupEffective)
        #expect(exercise.sets.map(\.setIndex) == [0, 1, 2, 3])
        #expect(exercise.displaySortedSets.map(\.localId) == [
            firstWarmup.localId,
            secondWarmup.localId,
            firstWorking.localId,
            secondWorking.localId
        ])
    }

    @Test func togglingWorkingSetTwiceRestoresDisplayOrderWithoutIndexDrift() {
        let exercise = WorkoutExercise(exerciseName: "杠铃卧推", orderIndex: 0)
        let first = WorkoutSet(setIndex: 0, weightKg: 60, reps: 8)
        let middle = WorkoutSet(setIndex: 1, weightKg: 65, reps: 6)
        let last = WorkoutSet(setIndex: 2, weightKg: 70, reps: 5)
        exercise.sets = [first, middle, last]

        exercise.toggleWarmup(middle)

        #expect(middle.isWarmupEffective)
        #expect(exercise.sets.map(\.setIndex) == [0, 1, 2])
        #expect(exercise.displaySortedSets.map(\.localId) == [middle.localId, first.localId, last.localId])

        exercise.toggleWarmup(middle)

        #expect(!middle.isWarmupEffective)
        #expect(exercise.sets.map(\.setIndex) == [0, 1, 2])
        #expect(exercise.displaySortedSets.map(\.localId) == [first.localId, middle.localId, last.localId])
    }

    @Test func cancelingWarmupDoesNotReplaceLastWorkingPrefillSource() {
        let exercise = WorkoutExercise(exerciseName: "杠铃卧推", orderIndex: 0)
        let warmup = WorkoutSet(setIndex: 0, weightKg: 20, reps: 10, setType: .warmup)
        let firstWorking = WorkoutSet(setIndex: 1, weightKg: 60, reps: 8)
        let lastWorking = WorkoutSet(setIndex: 2, weightKg: 70, reps: 6)
        exercise.sets = [warmup, firstWorking, lastWorking]

        exercise.toggleWarmup(warmup)

        #expect(exercise.lastWorkingSetValues.weightKg == 70)
        #expect(exercise.lastWorkingSetValues.reps == 6)
    }

    @Test func legacyWarmupRawValueCancelsInOneToggleWithoutChangingIndex() {
        let exercise = WorkoutExercise(exerciseName: "杠铃卧推", orderIndex: 0)
        let legacyWarmup = WorkoutSet(setIndex: 2, weightKg: 20, reps: 10)
        legacyWarmup.setTypeRaw = WorkoutSetType.warmup.rawValue
        legacyWarmup.isWarmup = false
        exercise.sets = [legacyWarmup]

        #expect(legacyWarmup.isWarmupEffective)

        exercise.toggleWarmup(legacyWarmup)

        #expect(!legacyWarmup.isWarmupEffective)
        #expect(legacyWarmup.setTypeRaw == WorkoutSetType.working.rawValue)
        #expect(legacyWarmup.setIndex == 2)
    }
}
