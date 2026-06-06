import Foundation

// MARK: - 按动作归并历史的稳定 key

extension WorkoutExercise {
    /// 按动作归并历史的稳定 key：内置 code 优先，其次自定义 id，最后回退动作名。
    /// 由动作库列表 PR 副标（`PRStats.latestPR()`）、`PersonalRecord` 检测等复用。
    var historyKey: String { builtinExerciseCode ?? customExerciseId?.uuidString ?? exerciseName }
}
