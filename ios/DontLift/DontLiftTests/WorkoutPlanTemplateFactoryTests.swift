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

    @Test func personalPlanDuplicateKeepsNotes() {
        let regular = PlanItem(exerciseName: "卧推", orderIndex: 0,
                               suggestedWeightKg: 80, note: "顶峰收缩")
        var drop = PlanItem.dropSet(orderIndex: 1, exerciseName: "飞鸟",
                                    segments: [WorkoutSetSegment(segmentIndex: 0, weightKg: 20, reps: 10)])
        drop.note = "控制离心"
        var superset = PlanItem.superset(orderIndex: 2, roundCount: 3,
                                         members: [
                                            PlanSupersetMember(exerciseName: "下拉", orderIndex: 0),
                                            PlanSupersetMember(exerciseName: "弯举", orderIndex: 1)
                                         ])
        superset.note = "组间不休息"

        let copies = [regular, drop, superset].map(PlanDetailView.weightlessCopyForDuplicate(_:))

        #expect(copies.map(\.note) == ["顶峰收缩", "控制离心", "组间不休息"])
    }

    @Test func planTemplateItemsCarryWorkoutNotes() {
        let workout = Workout(planId: nil, title: "胸推", endedAt: Date())
        workout.note = "本周减载"
        let single = WorkoutExercise(builtinExerciseCode: "BB_BENCH", exerciseName: "卧推", orderIndex: 0)
        single.note = "顶峰收缩 1 秒"
        single.sets = [WorkoutSet(setIndex: 0, weightKg: 80, reps: 8, completed: true, setType: .working)]
        let first = WorkoutExercise(exerciseName: "弯举", orderIndex: 1)
        first.sets = [WorkoutSet(setIndex: 0, weightKg: 20, reps: 10, completed: true, setType: .working),
                      WorkoutSet(setIndex: 1, weightKg: 20, reps: 10, completed: true, setType: .working)]
        let second = WorkoutExercise(exerciseName: "臂屈伸", orderIndex: 2)
        second.sets = [WorkoutSet(setIndex: 0, weightKg: 30, reps: 10, completed: true, setType: .working),
                       WorkoutSet(setIndex: 1, weightKg: 30, reps: 10, completed: true, setType: .working)]
        workout.exercises = [single, first, second]
        workout.appendSingleExerciseUnit(for: single)
        workout.appendSupersetUnit(first: first, second: second, roundCount: 2, note: "组间不休息")

        let items = workout.planTemplateItems()

        #expect(workout.note == "本周减载")
        #expect(items.count == 2)
        #expect(items.first { !$0.isSuperset }?.note == "顶峰收缩 1 秒")
        #expect(items.first { $0.isSuperset }?.note == "组间不休息")
    }

    // MARK: 历史手动另存资格

    @Test func historySaveIsAvailableRegardlessOfPlanSource() {
        let noPlan = finishedWorkout(planId: nil)
        let personal = finishedWorkout(planId: UUID())
        let team = finishedWorkout(planId: nil)
        team.sourceShareId = UUID()
        team.sourceShareVersionId = UUID()

        #expect(noPlan.canSaveAsPersonalPlanFromHistory)
        #expect(personal.canSaveAsPersonalPlanFromHistory)
        #expect(team.canSaveAsPersonalPlanFromHistory)
        // 完成页提示仍保持原条件：个人计划来源不默认展示，已保存过不再展示。
        #expect(noPlan.canOfferSaveAsPlanTemplate(alreadySaved: false))
        #expect(!noPlan.canOfferSaveAsPlanTemplate(alreadySaved: true))
        #expect(!personal.canOfferSaveAsPlanTemplate(alreadySaved: false))
        #expect(team.canOfferSaveAsPlanTemplate(alreadySaved: false))
    }

    @Test func historySaveRequiresFinishedLiveWorkoutWithFormalSets() {
        let inProgress = finishedWorkout(planId: nil)
        inProgress.endedAt = nil
        let deleted = finishedWorkout(planId: nil)
        deleted.deletedAt = Date()

        let incompleteOnly = Workout(planId: nil, title: "空", endedAt: Date())
        let pending = WorkoutExercise(exerciseName: "卧推", orderIndex: 0)
        pending.sets = [WorkoutSet(setIndex: 0, weightKg: 60, reps: 8, completed: false, setType: .working)]
        incompleteOnly.exercises = [pending]

        let warmupOnly = Workout(planId: nil, title: "热身", endedAt: Date())
        let warm = WorkoutExercise(exerciseName: "卧推", orderIndex: 0)
        warm.sets = [WorkoutSet(setIndex: 0, weightKg: 20, reps: 10, completed: true, setType: .warmup)]
        warmupOnly.exercises = [warm]

        let empty = Workout(planId: nil, title: "无动作", endedAt: Date())

        for workout in [inProgress, deleted, incompleteOnly, warmupOnly, empty] {
            #expect(!workout.canSaveAsPersonalPlanFromHistory)
        }
        #expect(warmupOnly.planTemplateItems().isEmpty)
        #expect(empty.planTemplateItems().isEmpty)
    }

    @Test func planTemplateDefaultNameFallsBackForGenericTitles() {
        #expect(Workout(title: "周二胸背").planTemplateDefaultName == "周二胸背")
        #expect(Workout(title: nil).planTemplateDefaultName == "训练模板")
        #expect(Workout(title: "   ").planTemplateDefaultName == "训练模板")
        #expect(Workout(title: "训练").planTemplateDefaultName == "训练模板")
    }

    // MARK: 历史另存内容转换

    @Test func planTemplateItemsKeepEachCompletedSetValue() throws {
        let workout = Workout(planId: nil, title: "胸", endedAt: Date())
        let bench = WorkoutExercise(builtinExerciseCode: "BB_BENCH", exerciseName: "卧推", orderIndex: 0)
        bench.sets = [
            WorkoutSet(setIndex: 0, weightKg: 60, reps: 10, completed: true, setType: .working),
            WorkoutSet(setIndex: 1, weightKg: 65, reps: 8, completed: true, setType: .working),
            WorkoutSet(setIndex: 2, weightKg: 70, reps: 6, completed: true, setType: .working)
        ]
        workout.exercises = [bench]

        let item = try #require(workout.planTemplateItems().first)
        let prescriptions = item.orderedSetPrescriptions

        #expect(prescriptions.map(\.weightKg) == [60, 65, 70])
        #expect(prescriptions.map(\.reps) == [10, 8, 6])
        #expect(prescriptions.allSatisfy { !$0.isWarmupEffective && $0.setType == .working })
        // 摘要只是兼容字段（顶组），不能反向覆盖逐组值。
        #expect(item.suggestedWeightKg == 70)
        #expect(item.suggestedReps == 6)
        #expect(item.suggestedSets == 3)
    }

    @Test func planTemplateItemsKeepCompletedWarmupAndDropIncompleteSets() throws {
        let workout = Workout(planId: nil, title: "胸", endedAt: Date())
        let bench = WorkoutExercise(builtinExerciseCode: "BB_BENCH", exerciseName: "卧推", orderIndex: 0)
        bench.sets = [
            WorkoutSet(setIndex: 0, weightKg: 20, reps: 10, completed: true, setType: .warmup),
            WorkoutSet(setIndex: 1, weightKg: 60, reps: 8, completed: true, setType: .working),
            WorkoutSet(setIndex: 2, weightKg: 65, reps: 6, completed: false, setType: .working)
        ]
        workout.exercises = [bench]

        let item = try #require(workout.planTemplateItems().first)
        let prescriptions = item.orderedSetPrescriptions

        #expect(prescriptions.count == 2)
        #expect(prescriptions.map(\.isWarmupEffective) == [true, false])
        #expect(prescriptions.map(\.weightKg) == [20, 60])
        #expect(prescriptions.map(\.reps) == [10, 8])
        #expect(item.suggestedSets == 1)
        #expect(item.formalSetCount == 1)
    }

    @Test func planTemplateItemsKeepEachDropSetGroupSegments() throws {
        let workout = Workout(planId: nil, title: "胸", endedAt: Date())
        let bench = WorkoutExercise(builtinExerciseCode: "BB_BENCH", exerciseName: "卧推", orderIndex: 0)
        bench.sets = [
            WorkoutSet(setIndex: 0, completed: true, setType: .drop, segments: [
                WorkoutSetSegment(segmentIndex: 0, weightKg: 80, reps: 8),
                WorkoutSetSegment(segmentIndex: 1, weightKg: 60, reps: 6)
            ]),
            WorkoutSet(setIndex: 1, completed: true, setType: .drop, segments: [
                WorkoutSetSegment(segmentIndex: 0, weightKg: 75, reps: 7),
                WorkoutSetSegment(segmentIndex: 1, weightKg: 55, reps: 8),
                WorkoutSetSegment(segmentIndex: 2, weightKg: 40, reps: 10)
            ]),
            WorkoutSet(setIndex: 2, completed: false, setType: .drop, segments: [
                WorkoutSetSegment(segmentIndex: 0, weightKg: 70, reps: 6)
            ])
        ]
        workout.exercises = [bench]
        workout.appendDropSetUnit(for: bench)

        let item = try #require(workout.planTemplateItems().first)
        let groups = item.dropSetPrescriptions

        #expect(item.isDropSet)
        #expect(groups.count == 2)
        #expect(groups[0].segments.map(\.weightKg) == [80, 60])
        #expect(groups[0].segments.map(\.reps) == [8, 6])
        #expect(groups[1].segments.map(\.weightKg) == [75, 55, 40])
        #expect(groups[1].segments.map(\.reps) == [7, 8, 10])
        #expect(groups.map(\.orderIndex) == [0, 1])
    }

    @Test func planTemplateItemsFollowActualOrderWithoutRestoringSkippedOrAlternatives() {
        // 来源计划含 A、B 且 A 有备选；实际跳过 B、临时新增 C。转换只看本次训练，不读来源计划。
        let workout = Workout(planId: UUID(), title: "计划训练", endedAt: Date())
        let a = WorkoutExercise(exerciseName: "A", orderIndex: 0)
        a.sets = [WorkoutSet(setIndex: 0, weightKg: 50, reps: 10, completed: true, setType: .working)]
        let b = WorkoutExercise(exerciseName: "B", orderIndex: 1)
        b.sets = [WorkoutSet(setIndex: 0, weightKg: 30, reps: 10, completed: false, setType: .working)]
        let c = WorkoutExercise(exerciseName: "C", orderIndex: 2)
        c.sets = [WorkoutSet(setIndex: 0, weightKg: 20, reps: 12, completed: true, setType: .working)]
        workout.exercises = [a, b, c]
        workout.appendSingleExerciseUnit(for: a, exerciseOptions: [
            PlanExerciseOption(exerciseName: "A"),
            PlanExerciseOption(exerciseName: "A 备选")
        ])
        workout.appendSingleExerciseUnit(for: b)
        workout.appendSingleExerciseUnit(for: c)

        let items = workout.planTemplateItems()

        #expect(items.map(\.exerciseName) == ["A", "C"])
        #expect(items.map(\.orderIndex) == [0, 1])
        #expect(items.allSatisfy { $0.alternatives == nil })
    }

    @Test func planTemplateItemsKeepNotesAndRestSemantics() throws {
        let workout = Workout(planId: nil, title: "全身", endedAt: Date())
        workout.note = "控制离心"
        let single = WorkoutExercise(exerciseName: "卧推", orderIndex: 0)
        single.note = "顶峰收缩"
        single.sets = [WorkoutSet(setIndex: 0, weightKg: 60, reps: 8, completed: true, setType: .working)]
        let drop = WorkoutExercise(exerciseName: "飞鸟", orderIndex: 1)
        drop.note = "慢放"
        drop.sets = [WorkoutSet(setIndex: 0, completed: true, setType: .drop, segments: [
            WorkoutSetSegment(segmentIndex: 0, weightKg: 20, reps: 10)
        ])]
        let first = WorkoutExercise(exerciseName: "下拉", orderIndex: 2)
        first.sets = [WorkoutSet(setIndex: 0, weightKg: 50, reps: 10, completed: true, setType: .working)]
        let second = WorkoutExercise(exerciseName: "弯举", orderIndex: 3)
        second.sets = [WorkoutSet(setIndex: 0, weightKg: 15, reps: 12, completed: true, setType: .working)]
        workout.exercises = [single, drop, first, second]
        workout.appendSingleExerciseUnit(for: single, restAfterSetSeconds: nil)
        workout.appendDropSetUnit(for: drop, restAfterSetSeconds: 0)
        workout.appendSupersetUnit(first: first, second: second, roundCount: 1,
                                   restAfterRoundSeconds: 90, note: "不休息")

        let items = workout.planTemplateItems()

        #expect(items.count == 3)
        #expect(items.map(\.note) == ["顶峰收缩", "慢放", "不休息"])
        #expect(items[0].restAfterSetSeconds == nil)
        #expect(items[1].restAfterSetSeconds == 0)
        #expect(items[2].supersetRestAfterRoundSeconds == 90)
        // 整体备注由表单预填（见 PlanEditorSeed），转换不改动原训练。
        #expect(workout.note == "控制离心")
    }

    private func finishedWorkout(planId: UUID?) -> Workout {
        let workout = Workout(planId: planId, title: "周二胸背", endedAt: Date())
        let bench = WorkoutExercise(builtinExerciseCode: "BB_BENCH", exerciseName: "卧推", orderIndex: 0)
        bench.sets = [WorkoutSet(setIndex: 0, weightKg: 80, reps: 8, completed: true, setType: .working)]
        workout.exercises = [bench]
        return workout
    }
}
