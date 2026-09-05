import Foundation
import SwiftData

/// 只传递值标识；动作别名解析复用主线程上的动作库，不跨执行器传递 SwiftData 对象。
nonisolated private struct BadgeExerciseIdentity: Hashable, Sendable {
    let code: String?
    let name: String
    let customId: UUID?
}

@ModelActor
actor BadgeHistoryReader {
    func readWorkouts() async throws -> [BadgeWorkoutSnapshot] {
        let workouts = try modelContext.fetch(FetchDescriptor<Workout>(
            predicate: #Predicate { $0.deletedAt == nil && $0.endedAt != nil },
            sortBy: [SortDescriptor(\.startedAt)]
        ))
        let identities = Set(workouts.flatMap { $0.exercises.map {
            BadgeExerciseIdentity(code: $0.builtinExerciseCode, name: $0.exerciseName, customId: $0.customExerciseId)
        } })
        // 同一动作只解析一次。关系读取和统计扫描均在后台进行。
        let resolved = await MainActor.run {
            Dictionary(uniqueKeysWithValues: identities.map { identity in
                let code = ExerciseLibrary.resolve(code: identity.code, name: identity.name)?.code ?? identity.code
                let lift: String?
                switch identity.customId == nil ? code : nil {
                case "BB_BENCH_PRESS": lift = "bench"
                case "BB_SQUAT": lift = "squat"
                case "DEADLIFT", "SUMO_DEADLIFT": lift = "deadlift"
                default: lift = nil
                }
                let key = ExerciseLibrary.canonicalHistoryKey(code: identity.code, name: identity.name, customId: identity.customId)
                return (identity, (key, lift))
            })
        }
        try Task.checkCancellation()
        return workouts.compactMap { workout in
            guard let endedAt = workout.endedAt else { return nil }
            return BadgeWorkoutSnapshot(
                id: workout.localId, planId: workout.planId, startedAt: workout.startedAt,
                endedAt: endedAt, updatedAt: workout.updatedAt,
                bodyWeightKgAtCompletion: workout.bodyWeightKgAtCompletion,
                exercises: workout.exercises.sorted { $0.orderIndex < $1.orderIndex }.map { exercise in
                    let identity = BadgeExerciseIdentity(code: exercise.builtinExerciseCode, name: exercise.exerciseName, customId: exercise.customExerciseId)
                    return BadgeExerciseSnapshot(
                        historyKey: resolved[identity]!.0, liftCode: resolved[identity]!.1,
                        planItemId: exercise.planItemId,
                        sets: exercise.sets.sorted { $0.setIndex < $1.setIndex }.map { set in
                            BadgeSetSnapshot(
                                weightKg: set.weightKg, reps: set.reps, completed: set.completed,
                                isWarmup: set.isWarmup || set.setTypeRaw == "warmup",
                                segments: (set.setTypeRaw == "drop" ? set.segments.sorted { $0.segmentIndex < $1.segmentIndex } : []).map {
                                    BadgeSegmentSnapshot(weightKg: $0.weightKg, reps: $0.reps)
                                },
                                isDropSet: set.setTypeRaw == "drop"
                            )
                        }
                    )
                }
            )
        }
    }
}
