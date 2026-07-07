import Foundation

enum WorkoutRestPolicy {
    struct NextSetCandidate: Equatable {
        let setId: UUID
        let exerciseName: String
        let setIndex: Int
        let weightKg: Double?
        let reps: Int?
    }

    /// 完成某组后启动休息的预计秒数。
    /// 同一动作内按展示顺序看上一组：上一组是正式组时继承其预计休息；上一组是热身或不存在时走动作默认值。
    static func plannedRestSeconds(completing set: WorkoutSet,
                                   in exercise: WorkoutExercise,
                                   fallbackSeconds: Int) -> Int {
        guard let previous = previousDisplaySet(before: set, in: exercise),
              !previous.isWarmupEffective,
              let planned = previous.plannedRestSeconds else {
            return fallbackSeconds
        }
        return planned
    }

    /// 休息完成后的真实秒数写回值。
    /// `continuedBaseSeconds` 是当前页面还活着时记录的累计基底；若页面重建导致它丢失，
    /// 已持久化的 `persistedActualRestSeconds` 仍可作为继续休息的累计基底。
    static func actualRestSecondsAfterCompletion(elapsedSeconds: Int,
                                                 continuedBaseSeconds: Int?,
                                                 persistedActualRestSeconds: Int?) -> Int {
        guard let base = continuedBaseSeconds ?? persistedActualRestSeconds else {
            return elapsedSeconds
        }
        return base + elapsedSeconds
    }

    /// 组间休息的“下一组”应跟随用户当前执行位置，而不是总是回到训练开头补漏。
    /// 找不到后续未完成组时，才从开头回补被跳过的组。
    static func nextSet(afterCompletedSetId anchorSetId: UUID?, in workout: Workout) -> NextSetCandidate? {
        let ordered = orderedSetCandidates(in: workout)
        guard !ordered.isEmpty else { return nil }

        guard let anchorSetId,
              let anchorIndex = ordered.firstIndex(where: { $0.set.localId == anchorSetId }) else {
            return ordered.first(where: { !$0.set.completed })?.candidate
        }

        if anchorIndex < ordered.index(before: ordered.endIndex),
           let forward = ordered[ordered.index(after: anchorIndex)...].first(where: { !$0.set.completed }) {
            return forward.candidate
        }

        return ordered[..<anchorIndex].first(where: { !$0.set.completed })?.candidate
    }

    private static func previousDisplaySet(before set: WorkoutSet, in exercise: WorkoutExercise) -> WorkoutSet? {
        let sorted = exercise.displaySortedSets
        guard let index = sorted.firstIndex(where: { $0.localId == set.localId }),
              index > sorted.startIndex else {
            return nil
        }
        return sorted[sorted.index(before: index)]
    }

    private struct OrderedSetCandidate {
        let set: WorkoutSet
        let candidate: NextSetCandidate
    }

    private static func orderedSetCandidates(in workout: Workout) -> [OrderedSetCandidate] {
        workout.trainingUnits.flatMap { unit -> [OrderedSetCandidate] in
            switch unit.kind {
            case .singleExercise, .dropSet:
                guard let exerciseId = unit.singleExerciseId,
                      let exercise = workout.exercise(id: exerciseId) else { return [] }
                return orderedSetCandidates(in: exercise)
            case .superset:
                guard let members = unit.superset?.members.sorted(by: { $0.orderIndex < $1.orderIndex }) else {
                    return []
                }
                return orderedSupersetSetCandidates(members: members, in: workout)
            }
        }
    }

    private static func orderedSetCandidates(in exercise: WorkoutExercise) -> [OrderedSetCandidate] {
        exercise.displaySortedSets.map { set in
            OrderedSetCandidate(set: set,
                                candidate: candidate(for: set, exerciseName: exercise.exerciseName))
        }
    }

    private static func orderedSupersetSetCandidates(
        members: [WorkoutSupersetMember],
        in workout: Workout
    ) -> [OrderedSetCandidate] {
        let exercises = members.compactMap { workout.exercise(id: $0.exerciseId) }
        let maxRoundCount = exercises.flatMap(\.sets).map(\.setIndex).max().map { $0 + 1 } ?? 0
        guard maxRoundCount > 0 else { return [] }

        return (0..<maxRoundCount).flatMap { roundIndex in
            exercises.compactMap { exercise in
                guard let set = exercise.sets
                    .sorted(by: { $0.setIndex < $1.setIndex })
                    .first(where: { $0.setIndex == roundIndex }) else {
                    return nil
                }
                return OrderedSetCandidate(set: set,
                                           candidate: candidate(for: set, exerciseName: exercise.exerciseName))
            }
        }
    }

    private static func candidate(for set: WorkoutSet, exerciseName: String) -> NextSetCandidate {
        let summary = set.summaryWeightReps
        return NextSetCandidate(setId: set.localId,
                                exerciseName: exerciseName,
                                setIndex: set.setIndex + 1,
                                weightKg: summary.weightKg,
                                reps: summary.reps)
    }
}
