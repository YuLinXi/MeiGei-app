import Foundation
import Testing
@testable import DontLift

@MainActor
struct WorkoutPlanTemplateFactoryTests {
    @Test func homepageStartCreatesNoPlanWorkoutShape() {
        let workout = Workout(planId: nil, title: "训练")

        #expect(workout.planId == nil)
        #expect(workout.sourceShareVersionId == nil)
    }

    @Test func teamShareWorkoutCanGenerateTemplateItemsFromCompletedWorkingSets() {
        let shareId = UUID()
        let versionId = UUID()
        let workout = Workout(planId: nil,
                              sourceShareId: shareId,
                              sourceShareVersionId: versionId,
                              title: "Team 推")
        let first = WorkoutExercise(builtinExerciseCode: "BB_BENCH", exerciseName: "卧推", orderIndex: 2)
        first.sets = [
            WorkoutSet(setIndex: 0, weightKg: 20, reps: 10, completed: true, setType: .warmup),
            WorkoutSet(setIndex: 1, weightKg: 80, reps: 8, completed: true, setType: .working),
            WorkoutSet(setIndex: 2, weightKg: 82.5, reps: 6, completed: true, setType: .working)
        ]
        let skipped = WorkoutExercise(builtinExerciseCode: "DB_FLY", exerciseName: "哑铃飞鸟", orderIndex: 1)
        skipped.sets = [WorkoutSet(setIndex: 0, weightKg: 12.5, reps: 12, completed: false, setType: .working)]
        workout.exercises = [first, skipped]
        workout.endedAt = workout.startedAt.addingTimeInterval(1800)

        let items = workout.planTemplateItems()

        #expect(workout.canOfferSaveAsPlanTemplate(alreadySaved: false))
        #expect(items.count == 1)
        #expect(items[0].exerciseName == "卧推")
        #expect(items[0].orderIndex == 0)
        #expect(items[0].suggestedSets == 2)
        #expect(items[0].suggestedReps == 6)
        #expect(items[0].suggestedWeightKg == 82.5)
    }

    @Test func personalPlanWorkoutDoesNotOfferSaveAsTemplate() {
        let workout = Workout(planId: UUID(), endedAt: Date())
        let exercise = WorkoutExercise(builtinExerciseCode: "BB_BENCH", exerciseName: "卧推", orderIndex: 0)
        exercise.sets = [WorkoutSet(setIndex: 0, weightKg: 80, reps: 8, completed: true, setType: .working)]
        workout.exercises = [exercise]

        #expect(!workout.canOfferSaveAsPlanTemplate(alreadySaved: false))
        #expect(!workout.canOfferSaveAsPlanTemplate(alreadySaved: true))
    }
}
