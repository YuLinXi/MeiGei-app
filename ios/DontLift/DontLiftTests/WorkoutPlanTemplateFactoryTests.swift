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
        workout.appendSingleExerciseUnit(for: first, restAfterSetSeconds: 120)
        workout.endedAt = workout.startedAt.addingTimeInterval(1800)

        let items = workout.planTemplateItems()

        #expect(workout.canOfferSaveAsPlanTemplate(alreadySaved: false))
        #expect(items.count == 1)
        #expect(items[0].exerciseName == "卧推")
        #expect(items[0].orderIndex == 0)
        #expect(items[0].suggestedSets == 2)
        #expect(items[0].suggestedReps == 6)
        #expect(items[0].suggestedWeightKg == 82.5)
        #expect(items[0].restAfterSetSeconds == 120)
        #expect(items[0].setPrescriptions?.count == 3)
        #expect(items[0].setPrescriptions?.first?.isWarmupEffective == true)
        #expect(items[0].setPrescriptions?.dropFirst().allSatisfy { !$0.isWarmupEffective } == true)
    }

    @Test func planTemplateItemsPreserveCompletedDropSetPrescription() {
        let workout = Workout(planId: nil, title: "胸推", endedAt: Date())
        let exercise = WorkoutExercise(builtinExerciseCode: "BB_BENCH", exerciseName: "卧推", orderIndex: 0)
        exercise.sets = [
            WorkoutSet(
                setIndex: 0,
                completed: true,
                setType: .drop,
                segments: [
                    WorkoutSetSegment(segmentIndex: 0, weightKg: 80, reps: 8),
                    WorkoutSetSegment(segmentIndex: 1, weightKg: 60, reps: 6)
                ]
            )
        ]
        workout.exercises = [exercise]
        workout.appendDropSetUnit(for: exercise, restAfterSetSeconds: 0)

        let items = workout.planTemplateItems()

        #expect(items.count == 1)
        #expect(items[0].isDropSet)
        #expect(items[0].suggestedSets == 1)
        #expect(items[0].suggestedWeightKg == 80)
        #expect(items[0].suggestedReps == 8)
        #expect(items[0].restAfterSetSeconds == 0)
        #expect(items[0].setPrescriptions?.first?.setType == .drop)
        #expect(items[0].setPrescriptions?.first?.segments.map(\.weightKg) == [80, 60])
        #expect(items[0].setPrescriptions?.first?.segments.map(\.reps) == [8, 6])
    }

    @Test func personalPlanWorkoutDoesNotOfferSaveAsTemplate() {
        let workout = Workout(planId: UUID(), endedAt: Date())
        let exercise = WorkoutExercise(builtinExerciseCode: "BB_BENCH", exerciseName: "卧推", orderIndex: 0)
        exercise.sets = [WorkoutSet(setIndex: 0, weightKg: 80, reps: 8, completed: true, setType: .working)]
        workout.exercises = [exercise]

        #expect(!workout.canOfferSaveAsPlanTemplate(alreadySaved: false))
        #expect(!workout.canOfferSaveAsPlanTemplate(alreadySaved: true))
    }

    @Test func personalPlanDuplicateKeepsRestWhileStrippingWeights() {
        let regular = PlanItem(exerciseName: "卧推", orderIndex: 0,
                               suggestedWeightKg: 80, restAfterSetSeconds: 120)
        var drop = PlanItem.dropSet(orderIndex: 1, exerciseName: "飞鸟",
                                    segments: [WorkoutSetSegment(segmentIndex: 0, weightKg: 20, reps: 10)])
        drop.restAfterSetSeconds = 0
        let superset = PlanItem.superset(orderIndex: 2, roundCount: 3,
                                         restAfterRoundSeconds: 180,
                                         members: [
                                            PlanSupersetMember(exerciseName: "下拉", orderIndex: 0, suggestedWeightKg: 50),
                                            PlanSupersetMember(exerciseName: "弯举", orderIndex: 1, suggestedWeightKg: 20)
                                         ])

        let copies = [regular, drop, superset].map(PlanDetailView.weightlessCopyForDuplicate(_:))

        #expect(copies.map(\.restAfterSetSeconds) == [120, 0, nil])
        #expect(copies[2].supersetRestAfterRoundSeconds == 180)
        #expect(copies[0].suggestedWeightKg == nil)
        #expect(copies[1].dropSetPrescriptions.flatMap(\.segments).allSatisfy { $0.weightKg == nil })
        #expect(copies[2].orderedSupersetMembers.allSatisfy { $0.suggestedWeightKg == nil })
    }
}
