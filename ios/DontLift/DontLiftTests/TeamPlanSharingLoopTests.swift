import Foundation
import Testing
@testable import DontLift

@MainActor
struct TeamPlanSharingLoopTests {
    @Test func shareSnapshotPreservesNotesWhileStrippingWeights() throws {
        var drop = PlanItem.dropSet(orderIndex: 1, exerciseName: "飞鸟",
                                    segments: [WorkoutSetSegment(segmentIndex: 0, weightKg: 20, reps: 10)])
        drop.note = "控制离心"
        var superset = PlanItem.superset(orderIndex: 2, roundCount: 3,
                                         members: [
                                            PlanSupersetMember(exerciseName: "下拉", orderIndex: 0, suggestedWeightKg: 50),
                                            PlanSupersetMember(exerciseName: "弯举", orderIndex: 1, suggestedWeightKg: 20)
                                         ])
        superset.note = "组间不休息"
        let plan = WorkoutPlan(
            name: "胸背",
            note: "本周减载",
            items: [
                PlanItem(exerciseName: "杠铃卧推", orderIndex: 0,
                         suggestedSets: 4, suggestedReps: 8, suggestedWeightKg: 80,
                         restAfterSetSeconds: 120, note: "顶峰收缩 1 秒"),
                drop,
                superset
            ],
            mode: .strict
        )

        let json = TeamService.weightlessItemsJSON(from: plan)
        let items = try JSONCoding.decoder.decode([PlanItem].self, from: Data(json.utf8))

        #expect(plan.note == "本周减载")
        #expect(items.map(\.note) == ["顶峰收缩 1 秒", "控制离心", "组间不休息"])
        #expect(items[0].suggestedWeightKg == nil)
        #expect(items[2].orderedSupersetMembers.allSatisfy { $0.suggestedWeightKg == nil })
    }

    @Test func shareSnapshotStripsWeightsButKeepsExercisePrescription() throws {
        let firstId = UUID()
        let secondId = UUID()
        let plan = WorkoutPlan(
            name: "胸背",
            items: [
                PlanItem(itemId: firstId,
                         builtinExerciseCode: "BB_BENCH_PRESS",
                         exerciseName: "杠铃卧推",
                         primaryMuscle: "胸",
                         equipmentType: "杠铃",
                         orderIndex: 1,
                         suggestedSets: 4,
                         suggestedReps: 8,
                         suggestedWeightKg: 80,
                         restAfterSetSeconds: 120),
                PlanItem(itemId: secondId,
                         builtinExerciseCode: "LAT_PULLDOWN",
                         exerciseName: "高位下拉",
                         primaryMuscle: "背",
                         equipmentType: "绳索",
                         orderIndex: 0,
                         suggestedSets: 3,
                         suggestedReps: 10,
                         suggestedWeightKg: 60)
            ],
            mode: .strict
        )

        let json = TeamService.weightlessItemsJSON(from: plan)
        let items = try JSONCoding.decoder.decode([PlanItem].self, from: Data(json.utf8))

        #expect(items.count == 2)
        #expect(items.map(\.itemId) == [firstId, secondId])
        #expect(items.map(\.suggestedWeightKg) == [nil, nil])
        #expect(items.map(\.restAfterSetSeconds) == [120, nil])
        #expect(items[0].exerciseName == "杠铃卧推")
        #expect(items[0].primaryMuscle == "胸")
        #expect(items[0].equipmentType == "杠铃")
        #expect(items[0].suggestedSets == 4)
        #expect(items[0].suggestedReps == 8)
    }

    @Test func shareSnapshotStripsNestedDropSetPrescriptionWeights() throws {
        let plan = WorkoutPlan(
            name: "递减胸推",
            items: [
                PlanItem(
                    builtinExerciseCode: "BB_BENCH_PRESS",
                    exerciseName: "杠铃卧推",
                    orderIndex: 0,
                    suggestedSets: 1,
                    suggestedReps: 8,
                    suggestedWeightKg: 80,
                    restAfterSetSeconds: 0,
                    setPrescriptions: [
                        PlanSetPrescription(
                            setType: .drop,
                            orderIndex: 0,
                            weightKg: 80,
                            reps: 8,
                            segments: [
                                WorkoutSetSegment(segmentIndex: 0, weightKg: 80, reps: 8),
                                WorkoutSetSegment(segmentIndex: 1, weightKg: 60, reps: 6)
                            ]
                        )
                    ]
                )
            ],
            mode: .adaptive
        )

        let json = TeamService.weightlessItemsJSON(from: plan)
        let items = try JSONCoding.decoder.decode([PlanItem].self, from: Data(json.utf8))

        let prescription = try #require(items.first?.setPrescriptions?.first)
        #expect(items.first?.suggestedWeightKg == nil)
        #expect(items.first?.restAfterSetSeconds == 0)
        #expect(prescription.setType == .drop)
        #expect(prescription.weightKg == nil)
        #expect(prescription.reps == 8)
        #expect(prescription.segments.map(\.weightKg) == [nil, nil])
        #expect(prescription.segments.map(\.reps) == [8, 6])
    }

    @Test func shareSnapshotKeepsWarmupPrescriptionRepsButStripsWeights() throws {
        let plan = WorkoutPlan(
            name: "热身胸推",
            items: [
                PlanItem(
                    builtinExerciseCode: "BB_BENCH_PRESS",
                    exerciseName: "杠铃卧推",
                    orderIndex: 0,
                    suggestedSets: 2,
                    suggestedReps: 8,
                    suggestedWeightKg: 80,
                    setPrescriptions: [
                        PlanSetPrescription(orderIndex: 0, weightKg: 20, reps: 10, isWarmup: true),
                        PlanSetPrescription(orderIndex: 1, weightKg: 40, reps: 5, isWarmup: true),
                        PlanSetPrescription(orderIndex: 2, weightKg: 80, reps: 8),
                        PlanSetPrescription(orderIndex: 3, weightKg: 80, reps: 8)
                    ]
                )
            ],
            mode: .adaptive
        )

        let json = TeamService.weightlessItemsJSON(from: plan)
        let item = try #require(JSONCoding.decoder.decode([PlanItem].self, from: Data(json.utf8)).first)
        let prescriptions = try #require(item.setPrescriptions)

        #expect(item.suggestedWeightKg == nil)
        #expect(item.suggestedSets == 2)
        #expect(prescriptions.map(\.weightKg) == [nil, nil, nil, nil])
        #expect(prescriptions.map(\.reps) == [10, 5, 8, 8])
        #expect(prescriptions.prefix(2).allSatisfy { $0.isWarmupEffective })
        #expect(prescriptions.dropFirst(2).allSatisfy { !$0.isWarmupEffective })
    }

    @Test func teamPlanShareCardUsesTotalCompletionAndLegacyFallbackCounts() throws {
        let shareId = UUID()
        let versionId = UUID()
        let teamId = UUID()
        let ownerId = UUID()
        let sourcePlanId = UUID()
        let itemId = UUID()
        let items = """
        [{
          "itemId": "\(itemId.uuidString)",
          "builtinExerciseCode": "FUTURE_PRESS",
          "exerciseName": "未来推举",
          "primaryMuscle": "肩",
          "equipmentType": "器械",
          "orderIndex": 0,
          "suggestedSets": 3,
          "suggestedReps": 12
        }]
        """
        let json = """
        {
          "shareId": "\(shareId.uuidString)",
          "versionId": "\(versionId.uuidString)",
          "teamId": "\(teamId.uuidString)",
          "ownerUserId": "\(ownerId.uuidString)",
          "ownerName": "队友",
          "sourcePlanId": "\(sourcePlanId.uuidString)",
          "title": "肩推",
          "versionNumber": 2,
          "planNameSnapshot": "肩推新版",
          "mode": "strict",
          "items": \(String(reflecting: items)),
          "adoptionCount": 5,
          "weeklyCompletionCount": 7
        }
        """

        let card = try JSONCoding.decoder.decode(TeamPlanShareCardDTO.self, from: Data(json.utf8))

        #expect(card.displayCopyCount == 5)
        #expect(card.displayCompletionCount == 7)
        #expect(card.sourcePlanId == sourcePlanId)
        #expect(card.planMode == .strict)
        #expect(card.itemCount == 1)
        #expect(card.exercisePreviewText == "未来推举")
        #expect(card.hasUnstartableItems == false)
    }

    @Test func directStartFromTeamShareKeepsSoftShareRelationAndNoPersonalPlanLink() {
        let shareId = UUID()
        let versionId = UUID()
        let item = PlanItem(builtinExerciseCode: "BB_BENCH_PRESS",
                            exerciseName: "杠铃卧推",
                            orderIndex: 0,
                            suggestedSets: 2,
                            suggestedReps: 8,
                            restAfterSetSeconds: 120)

        let workout = PlanWorkoutBuilder.workout(title: "Team 胸推",
                                                 items: [item],
                                                 mode: .adaptive,
                                                 lookup: .empty)
        workout.sourceShareId = shareId
        workout.sourceShareVersionId = versionId
        workout.sourcePlanNameSnapshot = "Team 胸推"

        #expect(workout.planId == nil)
        #expect(workout.sourceShareId == shareId)
        #expect(workout.sourceShareVersionId == versionId)
        #expect(workout.sourcePlanNameSnapshot == "Team 胸推")
        #expect(workout.exercises.first?.planItemId == item.itemId)
        #expect(workout.exercises.first?.sets.count == 2)
        #expect(workout.exercises.first?.sets.allSatisfy { !$0.completed } == true)
        #expect(workout.trainingUnits.first?.restAfterSetSeconds == 120)
    }

    @Test func checkinSummaryPreservesDropSetSegments() {
        let workout = Workout(title: "胸推", startedAt: Date(), endedAt: Date())
        let exercise = WorkoutExercise(builtinExerciseCode: "BB_BENCH_PRESS",
                                       exerciseName: "杠铃卧推",
                                       orderIndex: 0)
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

        let summary = CheckinSummary(workout: workout)
        let set = summary.exercises.first?.sets.first

        #expect(summary.totalSets == 1)
        #expect(summary.totalVolumeKg == 80 * 8 + 60 * 6)
        #expect(set?.setType == .drop)
        #expect(set?.segments?.map(\.weightKg) == [80, 60])
        #expect(set?.segments?.map(\.reps) == [8, 6])
    }

    @Test func completedTeamShareWorkoutCanBeSavedAsPlanTemplateOnce() {
        let workout = Workout(planId: nil,
                              sourceShareId: UUID(),
                              sourceShareVersionId: UUID(),
                              title: "Team 腿")
        let exercise = WorkoutExercise(builtinExerciseCode: "BB_SQUAT",
                                       exerciseName: "杠铃深蹲",
                                       primaryMuscle: "腿",
                                       orderIndex: 0)
        exercise.sets = [
            WorkoutSet(setIndex: 0, weightKg: 40, reps: 10, completed: true, setType: .warmup),
            WorkoutSet(setIndex: 1, weightKg: 100, reps: 6, completed: true, setType: .working),
            WorkoutSet(setIndex: 2, weightKg: 105, reps: 5, completed: true, setType: .working)
        ]
        workout.exercises = [exercise]
        workout.endedAt = workout.startedAt.addingTimeInterval(1200)

        let templateItems = workout.planTemplateItems()

        #expect(workout.canOfferSaveAsPlanTemplate(alreadySaved: false))
        #expect(!workout.canOfferSaveAsPlanTemplate(alreadySaved: true))
        #expect(templateItems.count == 1)
        #expect(templateItems[0].exerciseName == "杠铃深蹲")
        #expect(templateItems[0].suggestedSets == 2)
        #expect(templateItems[0].suggestedReps == 5)
        #expect(templateItems[0].suggestedWeightKg == 105)
        #expect(templateItems[0].setPrescriptions?.count == 3)
        #expect(templateItems[0].setPrescriptions?.first?.isWarmupEffective == true)
    }

    @Test func confirmDialogRunsActionBeforeOptionalStateIsCleared() {
        let shareId = UUID()
        var pendingShareId: UUID? = shareId
        var isPresented = true
        var capturedShareId: UUID?

        PaperConfirmDialogLifecycle.confirm {
            capturedShareId = pendingShareId
        } dismiss: {
            isPresented = false
            pendingShareId = nil
        }

        #expect(capturedShareId == shareId)
        #expect(isPresented == false)
        #expect(pendingShareId == nil)
    }
}
