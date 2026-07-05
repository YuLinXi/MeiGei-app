import Foundation
import Testing
@testable import DontLift

@MainActor
struct TeamPlanSharingLoopTests {
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
                         suggestedWeightKg: 80),
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
        #expect(prescription.setType == .drop)
        #expect(prescription.weightKg == nil)
        #expect(prescription.reps == 8)
        #expect(prescription.segments.map(\.weightKg) == [nil, nil])
        #expect(prescription.segments.map(\.reps) == [8, 6])
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
                            suggestedReps: 8)

        let workout = Workout(planId: nil,
                              sourceShareId: shareId,
                              sourceShareVersionId: versionId,
                              sourcePlanNameSnapshot: "Team 胸推",
                              title: "Team 胸推")
        let exercise = WorkoutExercise(builtinExerciseCode: item.builtinExerciseCode,
                                       exerciseName: item.displayExerciseName,
                                       orderIndex: 0,
                                       planItemId: item.itemId)
        exercise.sets = PlanPrefill.sets(for: item, mode: .adaptive, history: [])
        workout.exercises = [exercise]

        #expect(workout.planId == nil)
        #expect(workout.sourceShareId == shareId)
        #expect(workout.sourceShareVersionId == versionId)
        #expect(workout.sourcePlanNameSnapshot == "Team 胸推")
        #expect(workout.exercises.first?.planItemId == item.itemId)
        #expect(workout.exercises.first?.sets.count == 2)
        #expect(workout.exercises.first?.sets.allSatisfy { !$0.completed } == true)
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

        #expect(summary.totalSets == 2)
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
