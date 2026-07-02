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
            guard !sets.isEmpty else { continue }
            let top = sets.flatMap(\.statEntries).max { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) }
            items.append(PlanItem(
                builtinExerciseCode: ex.builtinExerciseCode,
                customExerciseId: ex.customExerciseId,
                exerciseName: ex.exerciseName,
                primaryMuscle: ex.primaryMuscle,
                orderIndex: items.count,
                suggestedSets: sets.count,
                suggestedReps: top?.reps,
                suggestedWeightKg: top?.weightKg,
                setPrescriptions: sets.enumerated().map { idx, set in
                    Self.planPrescription(from: set, orderIndex: idx)
                }
            ))
        }
        return items
    }

    private static func planPrescription(from set: WorkoutSet, orderIndex: Int) -> PlanSetPrescription {
        if set.isDropSet {
            let segments = set.effectiveSegments.enumerated().map { idx, segment in
                WorkoutSetSegment(segmentId: segment.segmentId,
                                  segmentIndex: idx,
                                  weightKg: segment.weightKg,
                                  reps: segment.reps)
            }
            let summary = set.summaryWeightReps
            return PlanSetPrescription(setType: .drop,
                                       orderIndex: orderIndex,
                                       weightKg: summary.weightKg,
                                       reps: summary.reps,
                                       segments: segments)
        }
        return PlanSetPrescription(setType: set.setType,
                                   orderIndex: orderIndex,
                                   weightKg: set.weightKg,
                                   reps: set.reps)
    }
}
