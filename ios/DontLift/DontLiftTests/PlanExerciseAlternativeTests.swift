import Foundation
import Testing
@testable import DontLift

@MainActor
struct PlanExerciseAlternativeTests {
    private let main = PlanExerciseOption(builtinExerciseCode: "MAIN_PRESS",
                                          exerciseName: "杠铃卧推",
                                          primaryMuscle: "胸",
                                          equipmentType: "杠铃")
    private let alternative = PlanExerciseOption(builtinExerciseCode: "ALT_PRESS",
                                                 exerciseName: "哑铃卧推",
                                                 primaryMuscle: "胸",
                                                 equipmentType: "哑铃")

    private func item(itemId: UUID = UUID(), modeWeight: Double = 80) -> PlanItem {
        PlanItem(itemId: itemId,
                 builtinExerciseCode: main.builtinExerciseCode,
                 exerciseName: main.exerciseName,
                 primaryMuscle: main.primaryMuscle,
                 equipmentType: main.equipmentType,
                 orderIndex: 0,
                 suggestedSets: 2,
                 suggestedReps: 8,
                 suggestedWeightKg: modeWeight,
                 setPrescriptions: [
                    PlanSetPrescription(orderIndex: 0, weightKg: 20, reps: 10, isWarmup: true),
                    PlanSetPrescription(orderIndex: 1, weightKg: modeWeight, reps: 8),
                    PlanSetPrescription(orderIndex: 2, weightKg: modeWeight, reps: 8)
                 ],
                 alternatives: [alternative])
    }

    private func finishedWorkout(code: String,
                                 name: String,
                                 itemId: UUID,
                                 weight: Double,
                                 date: Date) -> Workout {
        let workout = Workout(startedAt: date, endedAt: date.addingTimeInterval(3600))
        let exercise = WorkoutExercise(builtinExerciseCode: code,
                                       exerciseName: name,
                                       orderIndex: 0,
                                       planItemId: itemId)
        exercise.sets = [WorkoutSet(setIndex: 0,
                                    weightKg: weight,
                                    reps: 8,
                                    completed: true,
                                    setType: .working)]
        workout.exercises = [exercise]
        return workout
    }

    @Test func oldPlanJSONDecodesWithoutAlternativesAndNewJSONRoundTrips() throws {
        let oldJSON = """
        [{
          "itemId": "\(UUID().uuidString)",
          "builtinExerciseCode": "MAIN_PRESS",
          "exerciseName": "杠铃卧推",
          "orderIndex": 0
        }]
        """
        let oldItem = try #require(JSONCoding.decoder.decode([PlanItem].self,
                                                              from: Data(oldJSON.utf8)).first)
        #expect(oldItem.alternatives == nil)

        let data = try JSONCoding.encoder.encode([item()])
        let decoded = try #require(JSONCoding.decoder.decode([PlanItem].self, from: data).first)
        #expect(decoded.usableAlternatives.map(\.historyKey) == [alternative.historyKey])
        #expect(decoded.exerciseOptions.map(\.displayExerciseName) == ["杠铃卧推", "哑铃卧推"])
    }

    @Test func duplicateAndInvalidAlternativesAreNotExposedToTraining() {
        var source = item()
        source.alternatives = [
            main,
            alternative,
            alternative,
            PlanExerciseOption(builtinExerciseCode: "UNKNOWN", exerciseName: "   ")
        ]

        #expect(source.usableAlternatives.map(\.historyKey) == [alternative.historyKey])
        #expect(source.exerciseOptions.count == 2)
    }

    @Test func builderPersistsOptionsModeAndDefaultSetsInWorkoutUnit() throws {
        let planItem = item()
        let workout = PlanWorkoutBuilder.workout(title: "胸",
                                                 items: [planItem],
                                                 mode: .strict,
                                                 lookup: .empty)
        let unit = try #require(workout.trainingUnits.first)

        #expect(unit.exerciseOptions?.map(\.historyKey) == [main.historyKey, alternative.historyKey])
        #expect(unit.planMode == .strict)
        #expect(unit.defaultSetSnapshots?.map(\.weightKg) == [20, 80, 80])

        let roundTrip = try #require(Workout.decodeUnits(workout.unitsJSON).first)
        #expect(roundTrip.exerciseOptions?.map(\.historyKey) == [main.historyKey, alternative.historyKey])
        #expect(roundTrip.defaultSetSnapshots?.map(\.reps) == [10, 8, 8])
    }

    @Test func strictAlternativeClearsWeightsAndSwitchingBackRestoresDefaults() throws {
        let planItem = item()
        let workout = PlanWorkoutBuilder.workout(title: "胸",
                                                 items: [planItem],
                                                 mode: .strict,
                                                 lookup: .empty)
        let unit = try #require(workout.trainingUnits.first)

        let alternativeSets = PlanPrefill.replacementSets(planItemId: planItem.itemId,
                                                          option: alternative,
                                                          unit: unit,
                                                          lookup: .empty)
        #expect(alternativeSets.map(\.weightKg) == [nil, nil, nil])
        #expect(alternativeSets.map(\.reps) == [10, 8, 8])
        #expect(alternativeSets.first?.isWarmupEffective == true)

        let defaultSets = PlanPrefill.replacementSets(planItemId: planItem.itemId,
                                                      option: main,
                                                      unit: unit,
                                                      lookup: .empty)
        #expect(defaultSets.map(\.weightKg) == [20, 80, 80])
    }

    @Test func adaptiveHistoriesStaySeparatedByPlanItemAndActualExercise() throws {
        let itemId = UUID()
        let planItem = item(itemId: itemId)
        let mainWorkout = finishedWorkout(code: "MAIN_PRESS",
                                          name: "杠铃卧推",
                                          itemId: itemId,
                                          weight: 80,
                                          date: Date(timeIntervalSince1970: 1_000))
        let alternativeWorkout = finishedWorkout(code: "ALT_PRESS",
                                                 name: "哑铃卧推",
                                                 itemId: itemId,
                                                 weight: 30,
                                                 date: Date(timeIntervalSince1970: 2_000))
        let lookup = PlanHistoryLookup.build(from: [alternativeWorkout, mainWorkout])
        let workout = PlanWorkoutBuilder.workout(title: "胸",
                                                 items: [planItem],
                                                 mode: .adaptive,
                                                 lookup: lookup)
        let unit = try #require(workout.trainingUnits.first)

        #expect(workout.exercises.first?.sets.first?.weightKg == 80)
        let alternativeSets = PlanPrefill.replacementSets(planItemId: itemId,
                                                          option: alternative,
                                                          unit: unit,
                                                          lookup: lookup)
        #expect(alternativeSets.first?.weightKg == 30)
    }

    @Test func alternativeCompletionDoesNotOverwriteOrAppendPlanItem() {
        let itemId = UUID()
        let planItem = item(itemId: itemId)
        let workout = finishedWorkout(code: "ALT_PRESS",
                                      name: "哑铃卧推",
                                      itemId: itemId,
                                      weight: 30,
                                      date: Date(timeIntervalSince1970: 2_000))

        let result = PlanWriteback.merge(planItems: [planItem], workout: workout)

        #expect(result.newItems.count == 1)
        #expect(result.newItems.first?.historyKey == main.historyKey)
        #expect(result.newItems.first?.suggestedWeightKg == 80)
        #expect(!result.changed)
        #expect(result.diffs.isEmpty)
    }

    @Test func teamShareKeepsAlternativesWhileStrippingPlanWeights() throws {
        let plan = WorkoutPlan(name: "胸", items: [item()], mode: .adaptive)
        let json = TeamService.weightlessItemsJSON(from: plan)
        let shared = try #require(JSONCoding.decoder.decode([PlanItem].self,
                                                            from: Data(json.utf8)).first)

        #expect(shared.suggestedWeightKg == nil)
        #expect(shared.orderedSetPrescriptions.allSatisfy { $0.weightKg == nil })
        #expect(shared.usableAlternatives.map(\.historyKey) == [alternative.historyKey])
    }
}
