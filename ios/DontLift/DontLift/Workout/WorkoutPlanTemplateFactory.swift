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
        for unit in trainingUnits {
            switch unit.kind {
            case .singleExercise:
                guard let exerciseId = unit.singleExerciseId,
                      let ex = exercise(id: exerciseId),
                      let item = planItem(from: ex, orderIndex: items.count) else { continue }
                items.append(item)
            case .superset:
                guard let superset = unit.superset,
                      superset.members.count == 2 else { continue }
                let members = superset.members.sorted { $0.orderIndex < $1.orderIndex }
                let planMembers = members.compactMap { member -> PlanSupersetMember? in
                    guard let ex = exercise(id: member.exerciseId),
                          let summary = supersetMemberSummary(from: ex) else { return nil }
                    return PlanSupersetMember(builtinExerciseCode: ex.builtinExerciseCode,
                                              customExerciseId: ex.customExerciseId,
                                              exerciseName: ex.exerciseName,
                                              primaryMuscle: ex.primaryMuscle,
                                              orderIndex: member.orderIndex,
                                              suggestedWeightKg: summary.weightKg,
                                              suggestedReps: summary.reps)
                }
                guard planMembers.count == 2 else { continue }
                items.append(PlanItem.superset(orderIndex: items.count,
                                               roundCount: superset.roundCount,
                                               restAfterRoundSeconds: superset.restAfterRoundSeconds,
                                               members: planMembers))
            }
        }
        return items
    }

    private func planItem(from ex: WorkoutExercise, orderIndex: Int) -> PlanItem? {
            let sets = ex.sets
                .filter(\.countsForStats)
                .sorted { $0.setIndex < $1.setIndex }
            guard !sets.isEmpty else { return nil }
            let top = sets.flatMap(\.statEntries).max { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) }
            return PlanItem(
                builtinExerciseCode: ex.builtinExerciseCode,
                customExerciseId: ex.customExerciseId,
                exerciseName: ex.exerciseName,
                primaryMuscle: ex.primaryMuscle,
                orderIndex: orderIndex,
                suggestedSets: sets.count,
                suggestedReps: top?.reps,
                suggestedWeightKg: top?.weightKg,
                setPrescriptions: sets.enumerated().map { idx, set in
                    Self.planPrescription(from: set, orderIndex: idx)
                }
            )
    }

    private func supersetMemberSummary(from ex: WorkoutExercise) -> (weightKg: Double?, reps: Int?)? {
        let sets = ex.sets.filter(\.countsForStats)
        guard !sets.isEmpty else { return nil }
        let top = sets.flatMap(\.statEntries).max { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) }
        return (top?.weightKg, top?.reps)
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
