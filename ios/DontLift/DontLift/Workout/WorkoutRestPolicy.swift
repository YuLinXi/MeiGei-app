import Foundation

enum WorkoutRestPolicy {

    /// 完成某组后启动休息的预计秒数。
    /// 同一动作内按展示顺序看上一组：上一组是正式组时继承其预计休息；上一组是热身或不存在时走动作默认值。
    static func plannedRestSeconds(completing set: WorkoutSet,
                                   in exercise: WorkoutExercise,
                                   fallbackSeconds: Int) -> Int {
        guard let previous = previousDisplaySet(before: set, in: exercise),
              previous.setType != .warmup,
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

    private static func previousDisplaySet(before set: WorkoutSet, in exercise: WorkoutExercise) -> WorkoutSet? {
        let sorted = exercise.displaySortedSets
        guard let index = sorted.firstIndex(where: { $0.localId == set.localId }),
              index > sorted.startIndex else {
            return nil
        }
        return sorted[sorted.index(before: index)]
    }
}
