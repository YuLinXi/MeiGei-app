import Foundation
import Testing
@testable import DontLift

@MainActor
struct SupersetTrainingUnitTests {
    @Test func appendSingleExerciseDoesNotDuplicateLegacyDerivedUnit() {
        let workout = Workout(title: "训练")
        let exercise = workoutExercise(name: "杠铃卧推", orderIndex: 0)
        workout.exercises = [exercise]

        workout.appendSingleExerciseUnit(for: exercise)

        #expect(workout.trainingUnits.count == 1)
        #expect(workout.trainingUnits.first?.kind == .singleExercise)
        #expect(workout.trainingUnits.first?.singleExerciseId == exercise.localId)
        #expect(workout.storedUnits.count == 1)
    }

    @Test func encodeUnitsKeepsExplicitEmptyArrayForSync() throws {
        let json = try #require(Workout.encodeUnits([]))

        #expect(json == "[]")
        #expect(Workout.decodeUnits(json).isEmpty)
    }

    @Test func invalidSupersetUnitsFallBackToSingleExerciseUnits() {
        let workout = Workout(title: "旧训练")
        let first = workoutExercise(name: "夹胸", orderIndex: 0)
        let second = workoutExercise(name: "下斜卧推", orderIndex: 1)
        let third = workoutExercise(name: "划船", orderIndex: 2)
        workout.exercises = [first, second, third]
        workout.unitsJSON = Workout.encodeUnits([
            WorkoutUnit(
                kind: .superset,
                orderIndex: 0,
                superset: WorkoutSupersetUnit(
                    roundCount: 3,
                    members: [
                        WorkoutSupersetMember(exerciseId: first.localId, orderIndex: 0),
                        WorkoutSupersetMember(exerciseId: second.localId, orderIndex: 1),
                        WorkoutSupersetMember(exerciseId: third.localId, orderIndex: 2)
                    ]
                )
            )
        ])

        let units = workout.trainingUnits

        #expect(units.count == 3)
        #expect(units.allSatisfy { $0.kind == .singleExercise })
        #expect(units.map(\.singleExerciseId) == [first.localId, second.localId, third.localId])
    }

    @Test func planSupersetKeepsOnlyTwoMembersAndCountsRounds() throws {
        let firstId = UUID()
        let secondId = UUID()
        let thirdId = UUID()
        let item = PlanItem.superset(
            orderIndex: 0,
            roundCount: 4,
            members: [
                planMember(id: firstId, name: "夹胸", orderIndex: 0, weight: 60, reps: 12),
                planMember(id: secondId, name: "下斜卧推", orderIndex: 1, weight: 40, reps: 15),
                planMember(id: thirdId, name: "划船", orderIndex: 2, weight: 50, reps: 10)
            ]
        )
        let plan = WorkoutPlan(name: "胸背", items: [item])

        #expect(item.isSuperset)
        #expect(item.orderedSupersetMembers.map(\.memberId) == [firstId, secondId])
        #expect(item.supersetRounds == 4)
        #expect(plan.totalSuggestedSets == 8)
        #expect(plan.totalExerciseCount == 2)
        #expect(item.unitDisplayName == "夹胸 + 下斜卧推")
    }

    @Test func supersetInputParsingAllowsDecimalWeightButIntegerRepsAndRounds() {
        #expect(supersetDecimalValue("60.5") == 60.5)
        #expect(supersetDecimalValue(" 60,5 ") == 60.5)
        #expect(supersetDecimalValue("") == nil)
        #expect(supersetIntValue("12") == 12)
        #expect(supersetIntValue("12.5") == nil)
        #expect(supersetIntValue("4") == 4)
    }

    @Test func planWorkoutBuilderCreatesSupersetUnitWithWorkingSets() throws {
        let item = PlanItem.superset(
            orderIndex: 0,
            roundCount: 4,
            restAfterRoundSeconds: 90,
            members: [
                planMember(name: "夹胸", orderIndex: 0, weight: 60.5, reps: 12),
                planMember(name: "下斜卧推", orderIndex: 1, weight: 40, reps: 15)
            ]
        )

        let workout = PlanWorkoutBuilder.workout(title: "胸背", items: [item], mode: .adaptive, lookup: .empty)
        let unit = try #require(workout.trainingUnits.first)
        let superset = try #require(unit.superset)
        let first = try #require(workout.exercises.sorted { $0.orderIndex < $1.orderIndex }.first)
        let second = try #require(workout.exercises.sorted { $0.orderIndex < $1.orderIndex }.last)

        #expect(workout.trainingUnits.count == 1)
        #expect(unit.kind == .superset)
        #expect(superset.roundCount == 4)
        #expect(superset.restAfterRoundSeconds == 90)
        #expect(superset.members.map(\.exerciseId) == [first.localId, second.localId])
        #expect(first.sets.count == 4)
        #expect(second.sets.count == 4)
        #expect(first.sets.allSatisfy { $0.setType == .working && !$0.completed })
        #expect(second.sets.allSatisfy { $0.setType == .working && !$0.completed })
        #expect(first.sets.sorted { $0.setIndex < $1.setIndex }.map(\.weightKg) == [Double?](repeating: 60.5, count: 4))
        #expect(second.sets.sorted { $0.setIndex < $1.setIndex }.map(\.reps) == [Int?](repeating: 15, count: 4))
        #expect(workout.totalExerciseCountForDisplay == 2)
    }

    @Test func planWorkoutBuilderCreatesDropSetUnitWithSegments() throws {
        let item = PlanItem.dropSet(
            orderIndex: 0,
            builtinExerciseCode: "BB_BENCH",
            exerciseName: "杠铃卧推",
            segments: [
                WorkoutSetSegment(segmentIndex: 0, weightKg: 80, reps: 8),
                WorkoutSetSegment(segmentIndex: 1, weightKg: 60, reps: 6)
            ]
        )

        let workout = PlanWorkoutBuilder.workout(title: "胸", items: [item], mode: .strict, lookup: .empty)
        let unit = try #require(workout.trainingUnits.first)
        let exercise = try #require(workout.exercises.first)
        let set = try #require(exercise.sets.first)

        #expect(workout.trainingUnits.count == 1)
        #expect(unit.kind == .dropSet)
        #expect(unit.singleExerciseId == exercise.localId)
        #expect(exercise.sets.count == 1)
        #expect(set.setType == .drop)
        #expect(!set.completed)
        #expect(set.segments.map(\.weightKg) == [80, 60])
        #expect(set.segments.map(\.reps) == [8, 6])
        #expect(workout.totalExerciseCountForDisplay == 1)
    }

    @Test func statsTeamSummaryPosterAndPRExpandSupersetMembers() throws {
        let workout = supersetWorkout(rounds: 4)
        let first = try #require(workout.exercises.first { $0.exerciseName == "夹胸" })
        let second = try #require(workout.exercises.first { $0.exerciseName == "下斜卧推" })

        let stats = WorkoutWeeklyStats.compute(
            workouts: [workout],
            reference: workout.startedAt,
            calendar: .currentMondayFirst
        )
        let summary = CheckinSummary(workout: workout)
        let poster = WorkoutPosterData(workout: workout)
        let summaryUnit = try #require(summary.units?.first)
        let posterLine = try #require(poster.exerciseLines.first)

        #expect(stats.sessionCount == 1)
        #expect(stats.setCount == 8)
        #expect(stats.repCount == 4 * (12 + 15))
        #expect(stats.volumeKg == 4.0 * (60.0 * 12.0 + 40.0 * 15.0))
        #expect(PRStats.latestPR(for: first.historyKey, in: [workout])?.weightKg == 60)
        #expect(PRStats.latestPR(for: second.historyKey, in: [workout])?.weightKg == 40)

        #expect(summary.totalSets == 8)
        #expect(summary.totalVolumeKg == 4.0 * (60.0 * 12.0 + 40.0 * 15.0))
        #expect(summaryUnit.kind == .superset)
        #expect(summaryUnit.title == "夹胸 + 下斜卧推")
        #expect(summaryUnit.roundCount == 4)
        #expect(summaryUnit.exercises.map(\.name) == ["夹胸", "下斜卧推"])

        #expect(poster.setCountText == "8")
        #expect(poster.exerciseLines.count == 1)
        #expect(posterLine.name == "超级组 · 夹胸 + 下斜卧推")
        #expect(posterLine.topSetText == "4 组 · 共 8 组动作")
    }

    @Test func adaptiveWritebackUpdatesSupersetMembersWithoutChangingStructure() throws {
        let firstMemberId = UUID()
        let secondMemberId = UUID()
        let itemId = UUID()
        let item = PlanItem.superset(
            itemId: itemId,
            orderIndex: 0,
            roundCount: 4,
            members: [
                planMember(id: firstMemberId, name: "夹胸", orderIndex: 0, weight: 50, reps: 10),
                planMember(id: secondMemberId, name: "下斜卧推", orderIndex: 1, weight: 30, reps: 12)
            ]
        )
        let workout = PlanWorkoutBuilder.workout(title: "胸背", items: [item], mode: .adaptive, lookup: .empty)
        workout.endedAt = workout.startedAt.addingTimeInterval(3600)
        for exercise in workout.exercises {
            for set in exercise.sets { set.completed = true }
        }
        let first = try #require(workout.exercises.first { $0.planItemId == firstMemberId })
        let second = try #require(workout.exercises.first { $0.planItemId == secondMemberId })
        first.sets.first { $0.setIndex == 2 }?.weightKg = 62.5
        first.sets.first { $0.setIndex == 2 }?.reps = 8
        second.sets.first { $0.setIndex == 3 }?.weightKg = 42.5
        second.sets.first { $0.setIndex == 3 }?.reps = 14

        let result = PlanWriteback.merge(planItems: [item], workout: workout)
        let updated = try #require(result.newItems.first)
        let members = updated.orderedSupersetMembers

        #expect(result.newItems.count == 1)
        #expect(result.changed)
        #expect(updated.itemId == itemId)
        #expect(updated.isSuperset)
        #expect(updated.supersetRounds == 4)
        #expect(members.map(\.memberId) == [firstMemberId, secondMemberId])
        #expect(members.map(\.exerciseName) == ["夹胸", "下斜卧推"])
        #expect(members.map(\.suggestedWeightKg) == [Double?](arrayLiteral: 62.5, 42.5))
        #expect(members.map(\.suggestedReps) == [Int?](arrayLiteral: 8, 14))
    }

    @Test func temporarySupersetIsNotWrittenBackAsPlanStructure() {
        let sourceItemId = UUID()
        let sourceItem = PlanItem(itemId: sourceItemId,
                                  exerciseName: "杠铃卧推",
                                  orderIndex: 0,
                                  suggestedSets: 1,
                                  suggestedReps: 5,
                                  suggestedWeightKg: 80)
        let workout = Workout(planId: UUID(), title: "计划训练")
        let sourceExercise = workoutExercise(name: "杠铃卧推", orderIndex: 0, planItemId: sourceItemId)
        sourceExercise.sets = [WorkoutSet(setIndex: 0, weightKg: 80, reps: 5, completed: true)]
        workout.exercises = [sourceExercise]
        workout.updateTrainingUnits([
            WorkoutUnit(kind: .singleExercise, orderIndex: 0, singleExerciseId: sourceExercise.localId)
        ])

        let first = workoutExercise(name: "夹胸", orderIndex: 1)
        first.sets = completedSets(rounds: 2, weight: 60, reps: 12)
        let second = workoutExercise(name: "下斜卧推", orderIndex: 2)
        second.sets = completedSets(rounds: 2, weight: 40, reps: 15)
        workout.exercises.append(first)
        workout.exercises.append(second)
        workout.appendSupersetUnit(first: first, second: second, roundCount: 2)

        let result = PlanWriteback.merge(planItems: [sourceItem], workout: workout)

        #expect(result.newItems.count == 1)
        #expect(result.newItems.first?.itemId == sourceItemId)
        #expect(result.newItems.first?.isSuperset == false)
    }

    @Test func planTemplateItemsPreserveCompletedSupersetStructure() throws {
        let workout = supersetWorkout(rounds: 3)

        let items = workout.planTemplateItems()
        let item = try #require(items.first)

        #expect(items.count == 1)
        #expect(item.isSuperset)
        #expect(item.supersetRounds == 3)
        #expect(item.totalMemberSuggestionTexts == ["夹胸:60×12", "下斜卧推:40×15"])
    }

    @Test func teamPlanShareStripsSupersetWeightsButKeepsStructureAndReps() throws {
        let item = PlanItem.superset(
            orderIndex: 0,
            roundCount: 4,
            restAfterRoundSeconds: 90,
            members: [
                planMember(name: "夹胸", orderIndex: 0, weight: 60, reps: 12),
                planMember(name: "下斜卧推", orderIndex: 1, weight: 40, reps: 15)
            ]
        )
        let plan = WorkoutPlan(name: "胸背", items: [item])

        let json = TeamService.weightlessItemsJSON(from: plan)
        let decoded = try JSONCoding.decoder.decode([PlanItem].self, from: Data(json.utf8))
        let shared = try #require(decoded.first)

        #expect(shared.isSuperset)
        #expect(shared.supersetRounds == 4)
        #expect(shared.supersetRestAfterRoundSeconds == 90)
        #expect(shared.orderedSupersetMembers.map(\.suggestedWeightKg) == [Double?](arrayLiteral: nil, nil))
        #expect(shared.orderedSupersetMembers.map(\.suggestedReps) == [Int?](arrayLiteral: 12, 15))
    }

    @Test func teamPlanShareStripsDropSetWeightsButKeepsStructureAndSegments() throws {
        let item = PlanItem.dropSet(
            orderIndex: 0,
            builtinExerciseCode: "BB_BENCH",
            exerciseName: "卧推",
            segments: [
                WorkoutSetSegment(segmentIndex: 0, weightKg: 80, reps: 8),
                WorkoutSetSegment(segmentIndex: 1, weightKg: 60, reps: 6)
            ]
        )
        let plan = WorkoutPlan(name: "胸", items: [item])

        let json = TeamService.weightlessItemsJSON(from: plan)
        let decoded = try JSONCoding.decoder.decode([PlanItem].self, from: Data(json.utf8))
        let shared = try #require(decoded.first)
        let prescription = try #require(shared.setPrescriptions?.first)

        #expect(shared.isDropSet)
        #expect(shared.suggestedSets == 1)
        #expect(shared.suggestedWeightKg == nil)
        #expect(prescription.setType == .drop)
        #expect(prescription.segments.map(\.weightKg) == [nil, nil])
        #expect(prescription.segments.map(\.reps) == [8, 6])
    }

    private func supersetWorkout(rounds: Int) -> Workout {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let workout = Workout(title: "胸背", startedAt: startedAt, timerStartedAt: startedAt)
        let first = workoutExercise(name: "夹胸", orderIndex: 0)
        first.sets = completedSets(rounds: rounds, weight: 60, reps: 12)
        let second = workoutExercise(name: "下斜卧推", orderIndex: 1)
        second.sets = completedSets(rounds: rounds, weight: 40, reps: 15)
        workout.exercises = [first, second]
        workout.appendSupersetUnit(first: first, second: second, roundCount: rounds)
        workout.endedAt = startedAt.addingTimeInterval(3600)
        return workout
    }

    private func workoutExercise(name: String,
                                 orderIndex: Int,
                                 planItemId: UUID? = nil) -> WorkoutExercise {
        WorkoutExercise(exerciseName: name, orderIndex: orderIndex, planItemId: planItemId)
    }

    private func completedSets(rounds: Int, weight: Double, reps: Int) -> [WorkoutSet] {
        (0..<rounds).map {
            WorkoutSet(setIndex: $0, weightKg: weight, reps: reps, completed: true, setType: .working)
        }
    }

    private func planMember(id: UUID = UUID(),
                            name: String,
                            orderIndex: Int,
                            weight: Double,
                            reps: Int) -> PlanSupersetMember {
        PlanSupersetMember(memberId: id,
                           exerciseName: name,
                           orderIndex: orderIndex,
                           suggestedWeightKg: weight,
                           suggestedReps: reps)
    }
}

private extension PlanItem {
    var totalMemberSuggestionTexts: [String] {
        orderedSupersetMembers.map {
            "\($0.exerciseName):\(formatKg($0.suggestedWeightKg ?? 0))×\($0.suggestedReps ?? 0)"
        }
    }
}
