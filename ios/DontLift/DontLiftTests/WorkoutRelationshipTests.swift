import Foundation
import SwiftData
import Testing
@testable import DontLift

@MainActor
struct WorkoutRelationshipTests {
    @Test func unparentedSetReportsItsPresetValues() {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        defer { withExtendedLifetime(context) {} }
        defer { withExtendedLifetime(container) {} }
        let set = WorkoutSet(setIndex: 0, weightKg: 60, reps: 8, completed: true)

        #expect(set.exercise == nil)
        #expect(set.summaryWeightReps.weightKg == 60)
        #expect(set.summaryWeightReps.reps == 8)
        #expect(set.statEntries.count == 1)
    }

    @Test func appendedAssistedSetSurvivesSaveFailure() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        defer { withExtendedLifetime(context) {} }
        defer { withExtendedLifetime(container) {} }
        let workout = try WorkoutSession.start({
            Workout(exercises: [WorkoutExercise(builtinExerciseCode: "ASSISTED_PULL_UP",
                                                exerciseName: "辅助引体向上", orderIndex: 0)])
        }, in: context)
        let exercise = try #require(workout.exercises.first)
        let set = WorkoutSet(setIndex: 0, weightKg: 20, reps: 8, completed: true)
        exercise.sets.append(set)
        let coordinator = WorkoutSaveCoordinator()
        var notified = false
        #expect(!coordinator.flush(in: context, onSaved: { notified = true }, persist: { _ in
            throw CocoaError(.fileWriteNoPermission)
        }))

        #expect(coordinator.hasFailure)
        #expect(!notified)
        #expect(set.exercise?.localId == exercise.localId)
        #expect(set.weightKg == 20)
        #expect(set.reps == 8)
        #expect(set.statEntries.first?.isAssistedWeight == true)
        #expect(workout.completedStatVolumeKg == 0)
        let reader = ModelContext(container)
        let stored = try #require(reader.fetch(FetchDescriptor<Workout>()).first)
        #expect(stored.exercises.first?.sets.isEmpty == true)
    }

    @Test func startingPlanRetainsItsTrainingUnitsAndChildren() throws {
        let items: [PlanItem] = [
            PlanItem(exerciseName: "卧推", orderIndex: 0, suggestedSets: 3,
                     suggestedReps: 8, suggestedWeightKg: 60, restAfterSetSeconds: 120,
                     alternatives: [PlanExerciseOption(builtinExerciseCode: "DB_BENCH_PRESS", exerciseName: "哑铃卧推")]),
            .dropSet(orderIndex: 1, exerciseName: "飞鸟", groupCount: 2,
                     segments: [WorkoutSetSegment(segmentIndex: 0, weightKg: 20, reps: 10),
                                WorkoutSetSegment(segmentIndex: 1, weightKg: 15, reps: 12)]),
            .superset(orderIndex: 2, roundCount: 2, restAfterRoundSeconds: 90,
                      members: [PlanSupersetMember(exerciseName: "弯举", orderIndex: 0,
                                                   suggestedWeightKg: 15, suggestedReps: 10),
                                PlanSupersetMember(exerciseName: "臂屈伸", orderIndex: 1,
                                                   suggestedWeightKg: 20, suggestedReps: 12)])
        ]
        for mode in [WorkoutPlanMode.strict, .adaptive] {
            let container = AppModelContainer.make(inMemory: true)
            defer { withExtendedLifetime(container) {} }
            let workout = try WorkoutSession.start({
                PlanWorkoutBuilder.workout(title: "三种训练单元", items: items, mode: mode, lookup: .empty)
            }, in: container.mainContext)

            #expect(workout.trainingUnits.map(\.kind) == [.singleExercise, .dropSet, .superset])
            #expect(workout.trainingUnits.map(\.orderIndex) == [0, 1, 2])
            #expect(workout.trainingUnits[0].restAfterSetSeconds == 120)
            #expect(workout.trainingUnits[0].exerciseOptions?.count == 2)
            #expect(workout.trainingUnits[0].defaultSetSnapshots?.map(\.weightKg) == [60, 60, 60])
            #expect(workout.trainingUnits[2].superset?.roundCount == 2)
            #expect(workout.trainingUnits[2].superset?.restAfterRoundSeconds == 90)
            let exercises = workout.exercises.sorted { $0.orderIndex < $1.orderIndex }
            #expect(exercises.map(\.planItemId) == [items[0].itemId, items[1].itemId]
                    + items[2].orderedSupersetMembers.map(\.memberId))
            #expect(exercises.map { $0.sets.count } == [3, 2, 2, 2])
            #expect(exercises[0].sets.allSatisfy { $0.weightKg == 60 && $0.reps == 8 && !$0.completed })
            #expect(exercises[1].sets.allSatisfy { $0.segments.map(\.weightKg) == [20, 15] })
            #expect(exercises.allSatisfy { $0.workout?.localId == workout.localId })
        }
    }

    @Test func insertedWorkoutRetainsChildGraphAfterRefetch() throws {
        let container = AppModelContainer.make(inMemory: true)
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let set = WorkoutSet(setIndex: 0, weightKg: 60, reps: 8)
        let exercise = WorkoutExercise(exerciseName: "卧推", orderIndex: 0, sets: [set])
        let workout = Workout(exercises: [exercise])
        context.insert(workout)
        try context.save()

        let reader = ModelContext(container)
        let stored = try #require(reader.fetch(FetchDescriptor<Workout>()).first)
        #expect(stored.exercises.count == 1)
        let storedExercise = try #require(stored.exercises.first)
        #expect(storedExercise.localId == exercise.localId)
        #expect(storedExercise.workout?.localId == workout.localId)
        #expect(storedExercise.sets.count == 1)
        let storedSet = try #require(storedExercise.sets.first)
        #expect(storedSet.localId == set.localId)
        #expect(storedSet.exercise?.localId == exercise.localId)
        #expect(storedSet.weightKg == 60)
        #expect(storedSet.reps == 8)
    }
}
