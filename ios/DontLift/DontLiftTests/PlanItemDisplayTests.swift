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

    @Test func adaptiveDetailMatchesBuilderWhenHistoryHasFewerSetsThanTemplate() throws {
        let item = PlanItem(builtinExerciseCode: "BB_BENCH",
                            exerciseName: "卧推",
                            orderIndex: 0,
                            suggestedSets: 5,
                            suggestedReps: 10,
                            suggestedWeightKg: 60)
        let lookup = historyLookup(for: item, snapshots: [
            SetSnapshot(weightKg: 60, reps: 10),
            SetSnapshot(weightKg: 65, reps: 8),
            SetSnapshot(weightKg: 65, reps: 6)
        ])

        let preview = PlanPrescriptionPreview.make(for: item, mode: .adaptive, lookup: lookup)
        let groups = PlanItemDisplay.groups(from: preview.sets)
        let workout = PlanWorkoutBuilder.workout(title: "推日", items: [item], mode: .adaptive, lookup: lookup)
        let builtSets = try #require(workout.exercises.first?.sets.sorted { $0.setIndex < $1.setIndex })

        #expect(groups.count == 3)
        #expect(groups.flatMap(\.values).map(\.weightKg) == [60, 65, 65])
        #expect(groups.flatMap(\.values).map(\.reps) == [10, 8, 6])
        #expect(preview.sets.map(\.weightKg) == builtSets.map(\.weightKg))
        #expect(preview.sets.map(\.reps) == builtSets.map(\.reps))
        #expect(PlanItemDisplay.templateBaselineSummary(for: item, comparedTo: preview.sets)
                == "5 组 · 60 kg × 10 次")
        if case .history = preview.source {
            #expect(Bool(true))
        } else {
            #expect(Bool(false))
        }
    }

    @Test func semanticComparisonCoversWarmupAndStrictArrangementButIgnoresIdentity() throws {
        let item = PlanItem(exerciseName: "卧推",
                            equipmentType: EquipmentType.barbell.rawValue,
                            orderIndex: 0,
                            suggestedSets: 2,
                            setPrescriptions: [
                                PlanSetPrescription(orderIndex: 0, weightKg: 20, reps: 12, isWarmup: true),
                                PlanSetPrescription(orderIndex: 1, weightKg: 60, reps: 10),
                                PlanSetPrescription(orderIndex: 2, weightKg: 65, reps: 8)
                            ])
        let planned = PlanPrefill.plannedSets(for: item)
        let sameValuesWithNewIdentities = [
            WorkoutSet(setIndex: 0, weightKg: 20, reps: 12, isWarmup: true),
            WorkoutSet(setIndex: 1, weightKg: 60, reps: 10),
            WorkoutSet(setIndex: 2, weightKg: 65, reps: 8)
        ]

        #expect(PlanItemDisplay.hasSameArrangement(planned, sameValuesWithNewIdentities))
        #expect(PlanItemDisplay.templateBaselineSummary(for: item, comparedTo: sameValuesWithNewIdentities) == nil)

        let changedWarmup = [
            WorkoutSet(setIndex: 0, weightKg: 20, reps: 12),
            WorkoutSet(setIndex: 1, weightKg: 60, reps: 10),
            WorkoutSet(setIndex: 2, weightKg: 65, reps: 8)
        ]
        #expect(!PlanItemDisplay.hasSameArrangement(planned, changedWarmup))
        #expect(PlanItemDisplay.templateBaselineSummary(for: item, comparedTo: changedWarmup)
                == "1 热身组 + 2 正式组 · 各组设置不同")

        let preview = PlanPrescriptionPreview.make(for: item, mode: .strict, lookup: .empty)
        let workout = PlanWorkoutBuilder.workout(title: "严格训练", items: [item], mode: .strict, lookup: .empty)
        let builtSets = try #require(workout.exercises.first?.sets.sorted { $0.setIndex < $1.setIndex })

        #expect(preview.source == .strict)
        #expect(PlanItemDisplay.groups(from: preview.sets).map(\.title) == ["热身组 1", "正式组 1", "正式组 2"])
        #expect(preview.sets.map(\.weightKg) == builtSets.map(\.weightKg))
        #expect(preview.sets.map(\.reps) == builtSets.map(\.reps))

        let missingReps = PlanItem(exerciseName: "肩推", orderIndex: 1, suggestedSets: 3)
        #expect(PlanPrefill.missingStrictRequiredItems(in: [missingReps]) == [missingReps])
    }

    @Test func dropSetDetailsKeepEveryHistoricalSegmentAndMatchBuilder() throws {
        let item = PlanItem.dropSet(
            orderIndex: 0,
            exerciseName: "绳索下压",
            equipmentType: EquipmentType.cable.rawValue,
            groupCount: 2,
            segments: [
                WorkoutSetSegment(segmentIndex: 0, weightKg: 80, reps: 8),
                WorkoutSetSegment(segmentIndex: 1, weightKg: 60, reps: 6),
                WorkoutSetSegment(segmentIndex: 2, weightKg: 40, reps: 10)
            ]
        )
        let snapshots = [
            SetSnapshot(weightKg: 85,
                        reps: 7,
                        setTypeRaw: WorkoutSetType.drop.rawValue,
                        segments: [
                            WorkoutSetSegment(segmentIndex: 0, weightKg: 85, reps: 7),
                            WorkoutSetSegment(segmentIndex: 1, weightKg: 65, reps: 6),
                            WorkoutSetSegment(segmentIndex: 2, weightKg: 45, reps: 9)
                        ]),
            SetSnapshot(weightKg: 80,
                        reps: 8,
                        setTypeRaw: WorkoutSetType.drop.rawValue,
                        segments: [
                            WorkoutSetSegment(segmentIndex: 0, weightKg: 80, reps: 8),
                            WorkoutSetSegment(segmentIndex: 1, weightKg: 60, reps: 7),
                            WorkoutSetSegment(segmentIndex: 2, weightKg: 40, reps: 10)
                        ])
        ]
        let lookup = historyLookup(for: item, snapshots: snapshots)

        let preview = PlanPrescriptionPreview.make(for: item, mode: .adaptive, lookup: lookup)
        let groups = PlanItemDisplay.groups(from: preview.sets)
        let workout = PlanWorkoutBuilder.workout(title: "递减组", items: [item], mode: .adaptive, lookup: lookup)
        let builtSets = try #require(workout.exercises.first?.sets.sorted { $0.setIndex < $1.setIndex })

        #expect(groups.count == 2)
        #expect(groups.allSatisfy { $0.kind == .drop })
        #expect(groups[0].values.map(\.weightKg) == [85, 65, 45])
        #expect(groups[0].values.map(\.reps) == [7, 6, 9])
        #expect(groups[1].values.map(\.weightKg) == [80, 60, 40])
        #expect(preview.sets.map(\.sortedSegments) == builtSets.map(\.sortedSegments))

        let summary = try #require(PlanItemDisplay.templateBaselineSummary(for: item, comparedTo: preview.sets))
        #expect(summary == "2 组 · 每组 3 段")
        #expect(!summary.contains("kg"))
    }

    @Test func supersetDisplayAndEmptyWeightTextMatchBuilderSemantics() throws {
        let item = PlanItem.superset(
            orderIndex: 0,
            roundCount: 4,
            restAfterRoundSeconds: 90,
            members: [
                PlanSupersetMember(exerciseName: "夹胸",
                                   equipmentType: EquipmentType.cable.rawValue,
                                   orderIndex: 0,
                                   suggestedWeightKg: 30,
                                   suggestedReps: 12),
                PlanSupersetMember(exerciseName: "俯卧撑",
                                   equipmentType: EquipmentType.bodyweight.rawValue,
                                   orderIndex: 1,
                                   suggestedReps: 15)
            ]
        )

        let members = PlanItemDisplay.supersetMembers(for: item)
        let workout = PlanWorkoutBuilder.workout(title: "胸部", items: [item], mode: .adaptive, lookup: .empty)
        let unit = try #require(workout.trainingUnits.first?.superset)
        let exercises = workout.exercises.sorted { $0.orderIndex < $1.orderIndex }

        #expect(item.supersetRounds == 4)
        #expect(unit.roundCount == 4)
        #expect(unit.restAfterRoundSeconds == 90)
        #expect(exercises[0].sets.map(\.weightKg) == [30, 30, 30, 30])
        #expect(exercises[0].sets.map(\.reps) == [12, 12, 12, 12])
        #expect(exercises[1].sets.map(\.weightKg) == [nil, nil, nil, nil])
        #expect(exercises[1].sets.map(\.reps) == [15, 15, 15, 15])
        #expect(PlanItemDisplay.valueText(weightKg: members[0].weightKg,
                                          reps: members[0].reps,
                                          equipmentType: members[0].equipmentType) == "30 kg × 12 次")
        #expect(PlanItemDisplay.valueText(weightKg: members[1].weightKg,
                                          reps: members[1].reps,
                                          equipmentType: members[1].equipmentType) == "自重 × 15 次")
        #expect(PlanItemDisplay.valueText(weightKg: nil,
                                          reps: 10,
                                          equipmentType: EquipmentType.dumbbell.rawValue) == "训练时填写 × 10 次")
        #expect(PlanItemDisplay.valueText(weightKg: 40,
                                          reps: nil,
                                          equipmentType: EquipmentType.barbell.rawValue) == "40 kg × 未设置 次")
    }

    private func historyLookup(for item: PlanItem, snapshots: [SetSnapshot]) -> PlanHistoryLookup {
        let performance = LatestExercisePerformance(date: Date(timeIntervalSince1970: 1_000), sets: snapshots)
        return PlanHistoryLookup(
            latestByPlanExercise: [
                PlanExerciseHistoryKey(planItemId: item.itemId, historyKey: item.historyKey): performance
            ],
            latestByHistoryKey: [:],
            lastWorkoutByPlanId: [:]
        )
    }
}
