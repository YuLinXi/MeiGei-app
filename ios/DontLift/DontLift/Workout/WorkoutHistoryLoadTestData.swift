#if DEBUG
import Foundation
import SwiftData

/// DEBUG-only 历史训练压测数据生成器。
///
/// 用于本地构造 1000/5000 workouts 数据集：每条训练 4-6 个动作、总 15-25 组。
/// 生成的数据仍是普通 `Workout` 原始记录，不新增 projection 持久化实体，也不参与同步特殊路径。
enum WorkoutHistoryLoadTestData {
    struct Result: Equatable {
        var workouts: Int
        var exercises: Int
        var sets: Int
    }

    @discardableResult
    @MainActor
    static func seed(
        count: Int,
        in context: ModelContext,
        startDate: Date = Date(timeIntervalSince1970: 1_700_000_000),
        titlePrefix: String = "压测训练"
    ) throws -> Result {
        guard count > 0 else { return Result(workouts: 0, exercises: 0, sets: 0) }

        var insertedExercises = 0
        var insertedSets = 0
        let catalog = BuiltinExercise.starter.prefix(12).map { ($0.code, $0.name, $0.category) }

        for workoutIndex in 0..<count {
            let startedAt = startDate.addingTimeInterval(Double(workoutIndex) * 86_400)
            let workout = Workout(
                title: "\(titlePrefix) \(workoutIndex + 1)",
                startedAt: startedAt,
                timerStartedAt: startedAt,
                endedAt: startedAt.addingTimeInterval(45 * 60)
            )

            let exerciseCount = 4 + (workoutIndex % 3)
            for exerciseIndex in 0..<exerciseCount {
                let source = catalog[(workoutIndex + exerciseIndex) % catalog.count]
                let exercise = WorkoutExercise(
                    builtinExerciseCode: source.0,
                    exerciseName: source.1,
                    primaryMuscle: source.2,
                    orderIndex: exerciseIndex
                )
                let setCount = 3 + ((workoutIndex + exerciseIndex) % 2)
                exercise.sets = (0..<setCount).map { setIndex in
                    let base = 40 + Double((workoutIndex + exerciseIndex + setIndex) % 80)
                    return WorkoutSet(
                        setIndex: setIndex,
                        weightKg: base,
                        reps: 6 + ((workoutIndex + setIndex) % 8),
                        completed: true,
                        setType: .working
                    )
                }
                insertedSets += exercise.sets.count
                insertedExercises += 1
                workout.exercises.append(exercise)
            }
            context.insert(workout)
        }

        try context.save()
        return Result(workouts: count, exercises: insertedExercises, sets: insertedSets)
    }
}
#endif
