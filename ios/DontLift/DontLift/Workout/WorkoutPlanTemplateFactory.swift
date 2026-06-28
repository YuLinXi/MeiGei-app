import Foundation

extension Workout {
    func canOfferSaveAsPlanTemplate(alreadySaved: Bool) -> Bool {
        isFinished
        && planId == nil
        && deletedAt == nil
        && !alreadySaved
        && !planTemplateItems().isEmpty
    }

    func planTemplateItems() -> [PlanItem] {
        var items: [PlanItem] = []
        for ex in exercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            let sets = ex.sets
                .filter(\.countsForStats)
                .sorted { $0.setIndex < $1.setIndex }
            guard let last = sets.last else { continue }
            items.append(PlanItem(
                builtinExerciseCode: ex.builtinExerciseCode,
                customExerciseId: ex.customExerciseId,
                exerciseName: ex.exerciseName,
                primaryMuscle: ex.primaryMuscle,
                orderIndex: items.count,
                suggestedSets: sets.count,
                suggestedReps: last.reps,
                suggestedWeightKg: last.weightKg
            ))
        }
        return items
    }
}
