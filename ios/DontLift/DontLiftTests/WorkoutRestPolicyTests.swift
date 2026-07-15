import Foundation
import SwiftData
import Testing
@testable import DontLift

@MainActor
struct WorkoutRestPolicyTests {

    @Test func workoutSetRestSecondsPersistInSwiftData() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let setId = UUID()
        let set = WorkoutSet(localId: setId,
                             setIndex: 0,
                             weightKg: 80,
                             reps: 5,
                             completed: true,
                             plannedRestSeconds: 120,
                             actualRestSeconds: 137,
                             setType: .working)

        context.insert(set)
        try context.save()

        var descriptor = FetchDescriptor<WorkoutSet>(
            predicate: #Predicate { $0.localId == setId }
        )
        descriptor.fetchLimit = 1
        let fetched = try #require(try context.fetch(descriptor).first)
        #expect(fetched.plannedRestSeconds == 120)
        #expect(fetched.actualRestSeconds == 137)
    }

    @Test func warmupPreviousSetUsesFallbackRestSeconds() {
        let exercise = WorkoutExercise(exerciseName: "杠铃卧推", orderIndex: 0)
        let warmup = WorkoutSet(setIndex: 0,
                                completed: true,
                                plannedRestSeconds: 45,
                                actualRestSeconds: 61,
                                setType: .warmup)
        let working = WorkoutSet(setIndex: 1, completed: true, setType: .working)
        exercise.sets = [warmup, working]

        let seconds = WorkoutRestPolicy.plannedRestSeconds(completing: working,
                                                           in: exercise,
                                                           fallbackSeconds: 90)

        #expect(seconds == 90)
    }

    @Test func workingPreviousSetUsesPlannedRestSecondsNotActualSeconds() {
        let exercise = WorkoutExercise(exerciseName: "杠铃卧推", orderIndex: 0)
        let first = WorkoutSet(setIndex: 0,
                               completed: true,
                               plannedRestSeconds: 120,
                               actualRestSeconds: 173,
                               setType: .working)
        let second = WorkoutSet(setIndex: 1, completed: true, setType: .working)
        exercise.sets = [first, second]

        let seconds = WorkoutRestPolicy.plannedRestSeconds(completing: second,
                                                           in: exercise,
                                                           fallbackSeconds: 90)

        #expect(seconds == 120)
    }

    @Test func workingPreviousSetWithoutPlannedRestFallsBack() {
        let exercise = WorkoutExercise(exerciseName: "杠铃卧推", orderIndex: 0)
        let first = WorkoutSet(setIndex: 0,
                               completed: true,
                               actualRestSeconds: 173,
                               setType: .working)
        let second = WorkoutSet(setIndex: 1, completed: true, setType: .working)
        exercise.sets = [first, second]

        let seconds = WorkoutRestPolicy.plannedRestSeconds(completing: second,
                                                           in: exercise,
                                                           fallbackSeconds: 90)

        #expect(seconds == 90)
    }

    @Test func workoutSetDTODecodesRestSecondsFromSyncPayload() throws {
        let id = UUID()
        let json = """
        {
          "id": "\(id.uuidString)",
          "setIndex": 0,
          "weightKg": 80,
          "reps": 5,
          "completed": true,
          "plannedRestSeconds": 120,
          "actualRestSeconds": 137,
          "setType": "working"
        }
        """

        let dto = try JSONCoding.decoder.decode(WorkoutSetDTO.self, from: Data(json.utf8))

        #expect(dto.plannedRestSeconds == 120)
        #expect(dto.actualRestSeconds == 137)
    }

    @Test func continuedRestUsesInMemoryBaseWhenAvailable() {
        let seconds = WorkoutRestPolicy.actualRestSecondsAfterCompletion(
            elapsedSeconds: 30,
            continuedBaseSeconds: 90,
            persistedActualRestSeconds: 90
        )

        #expect(seconds == 120)
    }

    @Test func continuedRestFallsBackToPersistedActualWhenViewStateWasRebuilt() {
        let seconds = WorkoutRestPolicy.actualRestSecondsAfterCompletion(
            elapsedSeconds: 30,
            continuedBaseSeconds: nil,
            persistedActualRestSeconds: 90
        )

        #expect(seconds == 120)
    }

    @Test func firstRestCompletionUsesElapsedSecondsWithoutExistingBase() {
        let seconds = WorkoutRestPolicy.actualRestSecondsAfterCompletion(
            elapsedSeconds: 90,
            continuedBaseSeconds: nil,
            persistedActualRestSeconds: nil
        )

        #expect(seconds == 90)
    }

    @Test func workoutFinishUsesRunningRestTargetDuration() throws {
        let restTimer = RestTimerController()
        let setId = UUID()
        restTimer.start(duration: 120, setId: setId)
        defer { restTimer.stop() }

        let event = try #require(restTimer.completeForWorkoutFinish())

        #expect(event.setId == setId)
        #expect(event.elapsedSeconds == 120)
    }

    @Test func nextSetAfterSkippedEarlierExerciseContinuesWithinCurrentExercise() throws {
        let skipped = workoutExercise(name: "杠铃卧推", orderIndex: 0, completed: [false])
        let current = workoutExercise(name: "坐姿划船", orderIndex: 1, completed: [true, false])
        let workout = workout(exercises: [skipped, current])

        let next = try #require(WorkoutRestPolicy.nextSet(
            afterCompletedSetId: current.sets[0].localId,
            in: workout
        ))

        #expect(next.exerciseName == "坐姿划船")
        #expect(next.setIndex == 2)
        #expect(next.setId == current.sets[1].localId)
    }

    @Test func nextSetAfterCurrentExerciseFinishedMovesForward() throws {
        let skipped = workoutExercise(name: "杠铃卧推", orderIndex: 0, completed: [false])
        let current = workoutExercise(name: "坐姿划船", orderIndex: 1, completed: [true])
        let nextExercise = workoutExercise(name: "高位下拉", orderIndex: 2, completed: [false])
        let workout = workout(exercises: [skipped, current, nextExercise])

        let next = try #require(WorkoutRestPolicy.nextSet(
            afterCompletedSetId: current.sets[0].localId,
            in: workout
        ))

        #expect(next.exerciseName == "高位下拉")
        #expect(next.setIndex == 1)
        #expect(next.setId == nextExercise.sets[0].localId)
    }

    @Test func nextSetWrapsBackToSkippedEarlierExerciseWhenNoForwardSetExists() throws {
        let skipped = workoutExercise(name: "杠铃卧推", orderIndex: 0, completed: [false])
        let current = workoutExercise(name: "坐姿划船", orderIndex: 1, completed: [true])
        let workout = workout(exercises: [skipped, current])

        let next = try #require(WorkoutRestPolicy.nextSet(
            afterCompletedSetId: current.sets[0].localId,
            in: workout
        ))

        #expect(next.exerciseName == "杠铃卧推")
        #expect(next.setIndex == 1)
        #expect(next.setId == skipped.sets[0].localId)
    }

    @Test func nextSetFallbackWithoutAnchorUsesFirstIncompleteSet() throws {
        let first = workoutExercise(name: "杠铃卧推", orderIndex: 0, completed: [false])
        let second = workoutExercise(name: "坐姿划船", orderIndex: 1, completed: [false])
        let workout = workout(exercises: [first, second])

        let next = try #require(WorkoutRestPolicy.nextSet(afterCompletedSetId: nil, in: workout))

        #expect(next.exerciseName == "杠铃卧推")
        #expect(next.setId == first.sets[0].localId)
    }

    @Test func nextSetAfterSupersetRoundContinuesToNextRoundBeforeSkippedEarlierExercise() throws {
        let skipped = workoutExercise(name: "杠铃卧推", orderIndex: 0, completed: [false])
        let firstMember = workoutExercise(name: "夹胸", orderIndex: 1, completed: [true, false])
        let secondMember = workoutExercise(name: "下斜卧推", orderIndex: 2, completed: [true, false])
        let workout = workout(exercises: [skipped, firstMember, secondMember])
        workout.updateTrainingUnits([
            WorkoutUnit(kind: .singleExercise,
                        orderIndex: 0,
                        singleExerciseId: skipped.localId),
            WorkoutUnit(kind: .superset,
                        orderIndex: 1,
                        superset: WorkoutSupersetUnit(
                            roundCount: 2,
                            members: [
                                WorkoutSupersetMember(exerciseId: firstMember.localId, orderIndex: 0),
                                WorkoutSupersetMember(exerciseId: secondMember.localId, orderIndex: 1)
                            ]
                        ))
        ])

        let next = try #require(WorkoutRestPolicy.nextSet(
            afterCompletedSetId: secondMember.sets[0].localId,
            in: workout
        ))

        #expect(next.exerciseName == "夹胸")
        #expect(next.setIndex == 2)
        #expect(next.setId == firstMember.sets[1].localId)
    }

    private func workout(exercises: [WorkoutExercise]) -> Workout {
        let workout = Workout(exercises: exercises)
        workout.updateTrainingUnits(exercises.enumerated().map { index, exercise in
            WorkoutUnit(kind: .singleExercise,
                        orderIndex: index,
                        singleExerciseId: exercise.localId)
        })
        return workout
    }

    private func workoutExercise(name: String, orderIndex: Int, completed: [Bool]) -> WorkoutExercise {
        let exercise = WorkoutExercise(exerciseName: name, orderIndex: orderIndex)
        exercise.sets = completed.enumerated().map { index, isCompleted in
            WorkoutSet(setIndex: index,
                       weightKg: 60 + Double(index) * 2.5,
                       reps: 10 - index,
                       completed: isCompleted,
                       setType: .working)
        }
        return exercise
    }
}
