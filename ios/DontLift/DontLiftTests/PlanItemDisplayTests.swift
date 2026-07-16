import Foundation
import Testing
@testable import DontLift

@MainActor
struct PlanItemDisplayTests {
    @Test func compactSummaryUsesStaticPlanSetsAndReps() {
        let item = PlanItem(exerciseName: "卧推",
                            orderIndex: 0,
                            suggestedSets: 4,
                            suggestedReps: 10,
                            suggestedWeightKg: 80)

        #expect(PlanItemDisplay.compactSummary(for: item) == "4 组 × 10 次")
        #expect(PlanItemDisplay.planGroups(for: item).map(\.title) == ["正式组 1", "正式组 2", "正式组 3", "正式组 4"])
    }

    @Test func compactSummaryDoesNotInventRepresentativeReps() {
        let item = PlanItem(exerciseName: "卧推",
                            orderIndex: 0,
                            suggestedSets: 2,
                            setPrescriptions: [
                                PlanSetPrescription(orderIndex: 0, reps: 10),
                                PlanSetPrescription(orderIndex: 1, reps: 8)
                            ])

        let groups = PlanItemDisplay.planGroups(for: item)

        #expect(PlanItemDisplay.compactSummary(for: item) == "2 组 · 次数不一")
        #expect(groups.flatMap(\.values).map(\.reps) == [10, 8])
    }

    @Test func dropSetSummaryAndDetailsKeepEverySegment() {
        let item = PlanItem.dropSet(
            orderIndex: 0,
            exerciseName: "绳索下压",
            groupCount: 2,
            segments: [
                WorkoutSetSegment(segmentIndex: 0, weightKg: 40, reps: 8),
                WorkoutSetSegment(segmentIndex: 1, weightKg: 30, reps: 10),
                WorkoutSetSegment(segmentIndex: 2, weightKg: 20, reps: 12)
            ]
        )

        let groups = PlanItemDisplay.planGroups(for: item)

        #expect(PlanItemDisplay.compactSummary(for: item) == "2 组 · 每组 3 段")
        #expect(groups.count == 2)
        #expect(groups.allSatisfy { $0.kind == .drop })
        #expect(groups[0].values.map(\.reps) == [8, 10, 12])
    }

    @Test func supersetSummaryAndDetailsKeepMembers() {
        let item = PlanItem.superset(
            orderIndex: 0,
            roundCount: 4,
            members: [
                PlanSupersetMember(exerciseName: "夹胸", orderIndex: 0, suggestedWeightKg: 50, suggestedReps: 12),
                PlanSupersetMember(exerciseName: "俯卧撑", orderIndex: 1, suggestedWeightKg: nil, suggestedReps: 15)
            ]
        )

        let members = PlanItemDisplay.supersetMembers(for: item)

        #expect(PlanItemDisplay.compactSummary(for: item) == "4 轮 · 2 动作")
        #expect(members.map(\.name) == ["夹胸", "俯卧撑"])
        #expect(members.map(\.reps) == [12, 15])
        #expect(members.map(\.weightKg) == [50, nil])
    }

    @Test func adaptiveDetailWeightsMatchHistoryPreview() {
        let item = PlanItem(builtinExerciseCode: "BB_BENCH",
                            exerciseName: "卧推",
                            orderIndex: 0,
                            suggestedSets: 2,
                            suggestedReps: 10,
                            suggestedWeightKg: 60)
        let exercise = WorkoutExercise(builtinExerciseCode: "BB_BENCH",
                                       exerciseName: "卧推",
                                       orderIndex: 0,
                                       planItemId: item.itemId,
                                       sets: [
                                        WorkoutSet(setIndex: 0, weightKg: 62.5, reps: 8, completed: true),
                                        WorkoutSet(setIndex: 1, weightKg: 65, reps: 5, completed: true)
                                       ])
        let history = [Workout(title: "推日",
                               startedAt: Date(timeIntervalSince1970: 1_000),
                               endedAt: Date(timeIntervalSince1970: 2_000),
                               exercises: [exercise])]

        let preview = PlanPrescriptionPreview.make(for: item, mode: .adaptive, history: history)
        let groups = PlanItemDisplay.groups(from: preview.sets)

        #expect(groups.flatMap(\.values).map(\.weightKg) == [62.5, 65])
        #expect(preview.sets.map(\.weightKg) == groups.flatMap(\.values).map(\.weightKg))
        if case .history = preview.source {
            #expect(Bool(true))
        } else {
            #expect(Bool(false))
        }
    }
}
