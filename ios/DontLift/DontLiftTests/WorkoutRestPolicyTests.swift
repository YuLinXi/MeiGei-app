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
}
