import Foundation
import SwiftData
import Testing
@testable import DontLift

@MainActor
struct WorkoutRestPolicyTests {
    private let testStore = WorkoutTestStore()

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

    @Test func completedWarmupPreviousSetUsesFinalTargetRestSeconds() throws {
        let exercise = try testStore.insert(WorkoutExercise(exerciseName: "杠铃卧推", orderIndex: 0))
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

        #expect(seconds == 45)
    }

    @Test func workingPreviousSetUsesPlannedRestSecondsNotActualSeconds() throws {
        let exercise = try testStore.insert(WorkoutExercise(exerciseName: "杠铃卧推", orderIndex: 0))
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

    @Test func workingPreviousSetWithoutPlannedRestFallsBack() throws {
        let exercise = try testStore.insert(WorkoutExercise(exerciseName: "杠铃卧推", orderIndex: 0))
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

    @Test func unfinishedPreviousRestFallsBackInsteadOfUsingProvisionalTarget() throws {
        let exercise = try testStore.insert(WorkoutExercise(exerciseName: "杠铃卧推", orderIndex: 0))
        let first = WorkoutSet(setIndex: 0,
                               completed: true,
                               plannedRestSeconds: 120,
                               setType: .working)
        let second = WorkoutSet(setIndex: 1, completed: true, setType: .working)
        exercise.sets = [first, second]

        let seconds = WorkoutRestPolicy.plannedRestSeconds(completing: second,
                                                           in: exercise,
                                                           fallbackSeconds: 75)

        #expect(seconds == 75)
    }

    @Test func defaultRestPriorityUsesActionThenGlobalThenNinetySeconds() {
        #expect(WorkoutRestPolicy.defaultRestSeconds(actionDefaultSeconds: 120, globalDefaultSeconds: 75) == 120)
        #expect(WorkoutRestPolicy.defaultRestSeconds(actionDefaultSeconds: nil, globalDefaultSeconds: 75) == 75)
        #expect(WorkoutRestPolicy.defaultRestSeconds(actionDefaultSeconds: nil, globalDefaultSeconds: nil) == 90)
    }

    @Test func disabledActionRestCanBeEnabledAgain() {
        #expect(WorkoutRestPolicy.defaultRestSeconds(actionDefaultSeconds: 0, globalDefaultSeconds: 90) == 0)
        #expect(WorkoutRestPolicy.defaultRestSeconds(actionDefaultSeconds: 75, globalDefaultSeconds: 90) == 75)
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

    @Test func continuationAddsFinalTargetToPlannedRest() {
        let seconds = WorkoutRestPolicy.finalPlannedRestSeconds(
            targetSeconds: 30,
            previousPlannedSeconds: 100,
            isContinuation: true
        )

        #expect(seconds == 130)
    }

    @Test func completedRestUsesAdjustedTargetInsteadOfActualElapsedTime() {
        let seconds = WorkoutRestPolicy.finalPlannedRestSeconds(
            targetSeconds: 100,
            previousPlannedSeconds: 90,
            isContinuation: false
        )

        #expect(seconds == 100)
    }

    @Test func workoutFinishUsesRunningRestTargetDuration() throws {
        let restTimer = RestTimerController()
        let setId = UUID()
        restTimer.start(duration: 120, setId: setId)
        defer { restTimer.stop() }

        let event = try #require(restTimer.completeForWorkoutFinish())

        #expect(event.setId == setId)
        #expect(event.elapsedSeconds == 120)
        #expect(event.targetSeconds == 120)
    }

    @Test func adjustedRestKeepsFinalTargetWhenEndedEarly() throws {
        let restTimer = RestTimerController()
        let setId = UUID()
        restTimer.start(duration: 90, setId: setId)
        defer { restTimer.stop() }
        restTimer.adjust(by: 10)
        restTimer.completeEarly()

        let event = try #require(restTimer.consumeCompletionEvent(matching: [setId]))
        #expect(event.targetSeconds == 100)
        #expect(event.elapsedSeconds < event.targetSeconds)
    }

    @Test func adjustedRestUsesFinalTargetWhenNaturallyFinalizedForWorkoutFinish() throws {
        let restTimer = RestTimerController()
        let setId = UUID()
        restTimer.start(duration: 90, setId: setId)
        defer { restTimer.stop() }
        restTimer.adjust(by: 10)

        let event = try #require(restTimer.completeForWorkoutFinish())
        #expect(event.targetSeconds == 100)
        #expect(event.elapsedSeconds == 100)
    }

    @Test func supersetNextRoundInheritsPreviousRoundAnchorFinalTarget() throws {
        let anchorExercise = try testStore.insert(WorkoutExercise(exerciseName: "下斜卧推", orderIndex: 1))
        let firstRound = WorkoutSet(setIndex: 0,
                                    completed: true,
                                    plannedRestSeconds: 100,
                                    actualRestSeconds: 62,
                                    setType: .working)
        let secondRound = WorkoutSet(setIndex: 1, completed: true, setType: .working)
        anchorExercise.sets = [firstRound, secondRound]

        let seconds = WorkoutRestPolicy.plannedRestSeconds(completing: secondRound,
                                                           in: anchorExercise,
                                                           fallbackSeconds: 75)

        #expect(seconds == 100)
    }

    @Test func firstSupersetRoundUsesRoundDefaultFallback() throws {
        let anchorExercise = try testStore.insert(WorkoutExercise(exerciseName: "下斜卧推", orderIndex: 1))
        let firstRound = WorkoutSet(setIndex: 0, completed: true, setType: .working)
        anchorExercise.sets = [firstRound]

        let seconds = WorkoutRestPolicy.plannedRestSeconds(completing: firstRound,
                                                           in: anchorExercise,
                                                           fallbackSeconds: 75)

        #expect(seconds == 75)
    }

    @Test func workoutUnitRestDefaultRoundTripsAndLegacyJSONRemainsReadable() throws {
        let exerciseId = UUID()
        let unit = WorkoutUnit(kind: .singleExercise,
                               orderIndex: 0,
                               singleExerciseId: exerciseId,
                               restAfterSetSeconds: 120)
        let json = try #require(Workout.encodeUnits([unit]))
        let roundTrip = try #require(Workout.decodeUnits(json).first)
        #expect(roundTrip.restAfterSetSeconds == 120)

        let legacy = """
        [{"unitId":"\(UUID())","kindRaw":"singleExercise","orderIndex":0,"singleExerciseId":"\(exerciseId)"}]
        """
        #expect(Workout.decodeUnits(legacy).first?.restAfterSetSeconds == nil)
    }

    @Test func nextSetAfterSkippedEarlierExerciseContinuesWithinCurrentExercise() throws {
        let skipped = try workoutExercise(name: "杠铃卧推", orderIndex: 0, completed: [false])
        let current = try workoutExercise(name: "坐姿划船", orderIndex: 1, completed: [true, false])
        let workout = try workout(exercises: [skipped, current])

        let next = try #require(WorkoutRestPolicy.nextSet(
            afterCompletedSetId: try setID(in: current, at: 0),
            in: workout
        ))

        #expect(next.exerciseName == "坐姿划船")
        #expect(next.setIndex == 2)
        #expect(try next.setId == setID(in: current, at: 1))
    }

    @Test func nextSetAfterCurrentExerciseFinishedMovesForward() throws {
        let skipped = try workoutExercise(name: "杠铃卧推", orderIndex: 0, completed: [false])
        let current = try workoutExercise(name: "坐姿划船", orderIndex: 1, completed: [true])
        let nextExercise = try workoutExercise(name: "高位下拉", orderIndex: 2, completed: [false])
        let workout = try workout(exercises: [skipped, current, nextExercise])

        let next = try #require(WorkoutRestPolicy.nextSet(
            afterCompletedSetId: try setID(in: current, at: 0),
            in: workout
        ))

        #expect(next.exerciseName == "高位下拉")
        #expect(next.setIndex == 1)
        #expect(try next.setId == setID(in: nextExercise, at: 0))
    }

    @Test func nextSetWrapsBackToSkippedEarlierExerciseWhenNoForwardSetExists() throws {
        let skipped = try workoutExercise(name: "杠铃卧推", orderIndex: 0, completed: [false])
        let current = try workoutExercise(name: "坐姿划船", orderIndex: 1, completed: [true])
        let workout = try workout(exercises: [skipped, current])

        let next = try #require(WorkoutRestPolicy.nextSet(
            afterCompletedSetId: try setID(in: current, at: 0),
            in: workout
        ))

        #expect(next.exerciseName == "杠铃卧推")
        #expect(next.setIndex == 1)
        #expect(try next.setId == setID(in: skipped, at: 0))
    }

    @Test func nextSetFallbackWithoutAnchorUsesFirstIncompleteSet() throws {
        let first = try workoutExercise(name: "杠铃卧推", orderIndex: 0, completed: [false])
        let second = try workoutExercise(name: "坐姿划船", orderIndex: 1, completed: [false])
        let workout = try workout(exercises: [first, second])

        let next = try #require(WorkoutRestPolicy.nextSet(afterCompletedSetId: nil, in: workout))

        #expect(next.exerciseName == "杠铃卧推")
        #expect(try next.setId == setID(in: first, at: 0))
    }

    @Test func nextSetAfterSupersetRoundContinuesToNextRoundBeforeSkippedEarlierExercise() throws {
        let skipped = try workoutExercise(name: "杠铃卧推", orderIndex: 0, completed: [false])
        let firstMember = try workoutExercise(name: "夹胸", orderIndex: 1, completed: [true, false])
        let secondMember = try workoutExercise(name: "下斜卧推", orderIndex: 2, completed: [true, false])
        let workout = try workout(exercises: [skipped, firstMember, secondMember])
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
            afterCompletedSetId: try setID(in: secondMember, at: 0),
            in: workout
        ))

        #expect(next.exerciseName == "夹胸")
        #expect(next.setIndex == 2)
        #expect(try next.setId == setID(in: firstMember, at: 1))
    }

    /// 夹具按显式索引定位组，不将关系数组顺序作为组身份。
    private func setID(in exercise: WorkoutExercise, at setIndex: Int) throws -> UUID {
        try #require(exercise.sets.first { $0.setIndex == setIndex }).localId
    }

    private func workout(exercises: [WorkoutExercise]) throws -> Workout {
        let workout = try testStore.insert(Workout(exercises: exercises))
        workout.updateTrainingUnits(exercises.enumerated().map { index, exercise in
            WorkoutUnit(kind: .singleExercise,
                        orderIndex: index,
                        singleExerciseId: exercise.localId)
        })
        return workout
    }

    private func workoutExercise(name: String, orderIndex: Int, completed: [Bool]) throws -> WorkoutExercise {
        let exercise = try testStore.insert(WorkoutExercise(exerciseName: name, orderIndex: orderIndex))
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
