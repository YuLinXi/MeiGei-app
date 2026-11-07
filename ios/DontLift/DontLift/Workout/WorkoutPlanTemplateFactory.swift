import Foundation

@MainActor extension Workout {
    /// 完成页「保存为计划模板」行动卡的默认展示条件：仅无个人计划来源、尚未保存过的训练。
    /// 历史详情的手动另存使用 `canSaveAsPersonalPlanFromHistory`，不要放宽这里的 `planId` 限制。
    func canOfferSaveAsPlanTemplate(alreadySaved: Bool) -> Bool {
        canSaveAsPersonalPlanFromHistory
        && planId == nil
        && !alreadySaved
    }

    /// 历史详情手动「另存为个人计划」资格：已完成、未软删且至少能转换出一个计划项。
    /// 不限制来源（无计划／个人计划／Team 分享版本均可），也不读取来源计划。
    var canSaveAsPersonalPlanFromHistory: Bool {
        isFinished && !planTemplateItems().isEmpty
    }

    /// 另存表单的默认计划名：训练标题为空、仅空白或为通用名「训练」时用「训练模板」。
    var planTemplateDefaultName: String {
        let title = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty || title == "训练" ? "训练模板" : title
    }

    func planTemplateItems() -> [PlanItem] {
        var items: [PlanItem] = []
        for unit in trainingUnits {
            switch unit.kind {
            case .singleExercise:
                guard let exerciseId = unit.singleExerciseId,
                      let ex = exercise(id: exerciseId),
                      let item = planItem(from: ex,
                                          restAfterSetSeconds: unit.restAfterSetSeconds,
                                          orderIndex: items.count) else { continue }
                items.append(item)
            case .dropSet:
                guard let exerciseId = unit.singleExerciseId,
                      let ex = exercise(id: exerciseId),
                      let item = dropSetPlanItem(from: ex,
                                                 restAfterSetSeconds: unit.restAfterSetSeconds,
                                                 orderIndex: items.count) else { continue }
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
                var supersetItem = PlanItem.superset(orderIndex: items.count,
                                                     roundCount: superset.roundCount,
                                                     restAfterRoundSeconds: superset.restAfterRoundSeconds,
                                                     members: planMembers)
                supersetItem.note = superset.note
                items.append(supersetItem)
            }
        }
        return items
    }

    private func planItem(from ex: WorkoutExercise,
                          restAfterSetSeconds: Int?,
                          orderIndex: Int) -> PlanItem? {
            let executionSets = ex.sets
                .filter { $0.completed && !$0.isDropSet }
                .sorted {
                    if $0.isWarmupEffective != $1.isWarmupEffective {
                        return $0.isWarmupEffective && !$1.isWarmupEffective
                    }
                    return $0.setIndex < $1.setIndex
                }
            let formalSets = executionSets.filter { !$0.isWarmupEffective }
            guard !formalSets.isEmpty else { return nil }
            let top = formalSets.flatMap(\.statEntries).max { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) }
            return PlanItem(
                builtinExerciseCode: ex.builtinExerciseCode,
                customExerciseId: ex.customExerciseId,
                exerciseName: ex.exerciseName,
                primaryMuscle: ex.primaryMuscle,
                orderIndex: orderIndex,
                suggestedSets: formalSets.count,
                suggestedReps: top?.reps,
                suggestedWeightKg: top?.weightKg,
                restAfterSetSeconds: restAfterSetSeconds,
                note: ex.note,
                setPrescriptions: executionSets.enumerated().map { idx, set in
                    Self.planPrescription(from: set, orderIndex: idx)
                }
            )
    }

    private func dropSetPlanItem(from ex: WorkoutExercise,
                                 restAfterSetSeconds: Int?,
                                 orderIndex: Int) -> PlanItem? {
        let dropSets = ex.sets
            .sorted(by: { $0.setIndex < $1.setIndex })
            .filter { $0.isDropSet && $0.countsForStats }
        guard let set = dropSets.first,
              !set.effectiveSegments.isEmpty else {
            return nil
        }
        let top = dropSets.flatMap(\.statEntries).max { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) }
        return PlanItem(unitKind: .dropSet,
                        builtinExerciseCode: ex.builtinExerciseCode,
                        customExerciseId: ex.customExerciseId,
                        exerciseName: ex.exerciseName,
                        primaryMuscle: ex.primaryMuscle,
                        orderIndex: orderIndex,
                        suggestedSets: dropSets.count,
                        suggestedReps: top?.reps,
                        suggestedWeightKg: top?.weightKg,
                        restAfterSetSeconds: restAfterSetSeconds,
                        note: ex.note,
                        setPrescriptions: dropSets.enumerated().map { idx, set in
                            Self.planPrescription(from: set, orderIndex: idx)
                        })
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
                                       isWarmup: false,
                                       segments: segments)
        }
        return PlanSetPrescription(setType: set.setType,
                                   orderIndex: orderIndex,
                                   weightKg: set.weightKg,
                                   reps: set.reps,
                                   isWarmup: set.isWarmupEffective)
    }
}
