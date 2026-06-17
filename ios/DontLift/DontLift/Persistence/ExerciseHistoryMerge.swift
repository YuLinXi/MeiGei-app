import Foundation
import SwiftData

/// 同名动作历史合并（一次性本地迁移，change `exercise-library-taxonomy-import`）。
///
/// 训记动作导入后，用户过去「手填」（无 builtinCode、无 customId）的训练条目其 `historyKey`
/// 回退到 `exerciseName`；若该名恰好等于某新内置动作名，则历史曲线会与新内置动作断成两条。
/// 本迁移把这类手填条目挂到同名内置动作的 `code` 上，使 `historyKey` 由 name 切到 code、历史连续。
///
/// - 仅本地：不新增同步实体、不动 LWW/幂等约定。
/// - 幂等：已挂 `code` 的条目不再处理，可安全重跑。
enum ExerciseHistoryMerge {

    /// 执行迁移，返回被合并（改挂 code）的条目数。
    @discardableResult
    static func run(in context: ModelContext) -> Int {
        // 内置动作 名 -> code（含 curated + imported）。重名时取首个（curated 在前，优先保留精选 code）。
        var nameToCode: [String: String] = [:]
        for ex in BuiltinExercise.starter where nameToCode[ex.name] == nil {
            nameToCode[ex.name] = ex.code
        }

        // 取全部训练条目，在内存里筛「按名归并的手填条目」：无 builtinCode 且无 customId。
        // （用户自身数据量小；避免 #Predicate 对可选字段的边界问题。）
        guard let all = try? context.fetch(FetchDescriptor<WorkoutExercise>()) else { return 0 }

        var migrated = 0
        for ex in all where ex.builtinExerciseCode == nil && ex.customExerciseId == nil {
            if let code = nameToCode[ex.exerciseName] {
                ex.builtinExerciseCode = code
                migrated += 1
            }
        }
        if migrated > 0 {
            try? context.save()
            #if DEBUG
            print("[ExerciseHistoryMerge] 已把 \(migrated) 条手填记录合并到同名内置动作 code")
            #endif
        }
        return migrated
    }
}
