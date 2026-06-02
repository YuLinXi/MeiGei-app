import Foundation
import SwiftData

/// 训练记录聚合根（对应后端 workout）。
/// 子节点 exercise/set 无独立同步信封，随聚合整体上传、服务端按 workoutId 全量替换（design.md D5）。
@Model
final class Workout: Syncable {
    @Attribute(.unique) var localId: UUID
    var serverId: UUID?
    var updatedAt: Date
    var deletedAt: Date?
    var version: Int
    var syncStatusRaw: String

    /// 来源计划模板（可空：徒手临时训练）。
    var planId: UUID?
    var title: String?
    var startedAt: Date
    var endedAt: Date?
    var note: String?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var exercises: [WorkoutExercise]

    init(
        localId: UUID = UUID(),
        planId: UUID? = nil,
        title: String? = nil,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        note: String? = nil,
        exercises: [WorkoutExercise] = [],
        now: Date = .now
    ) {
        self.localId = localId
        self.serverId = nil
        self.updatedAt = now
        self.deletedAt = nil
        self.version = 0
        self.syncStatusRaw = SyncStatus.pendingCreate.rawValue
        self.planId = planId
        self.title = title
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.note = note
        self.exercises = exercises
    }
}

// MARK: - 会话生命周期派生状态（不新增持久化字段，见 workout-session-lifecycle）

extension Workout {
    /// 进行中会话：未删除且未结束。全局至多一个（由 `WorkoutSession.beginSession` 守卫保证）。
    var isActive: Bool { deletedAt == nil && endedAt == nil }
    /// 已完成会话：未删除且已结束。
    var isFinished: Bool { deletedAt == nil && endedAt != nil }
}

/// 训练中的一个动作条目（聚合子节点，不单独同步）。
@Model
final class WorkoutExercise {
    @Attribute(.unique) var localId: UUID
    var builtinExerciseCode: String?
    var customExerciseId: UUID?
    var exerciseName: String
    var primaryMuscle: String?
    var orderIndex: Int
    var note: String?

    var workout: Workout?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise)
    var sets: [WorkoutSet]

    init(
        localId: UUID = UUID(),
        builtinExerciseCode: String? = nil,
        customExerciseId: UUID? = nil,
        exerciseName: String,
        primaryMuscle: String? = nil,
        orderIndex: Int,
        note: String? = nil,
        sets: [WorkoutSet] = []
    ) {
        self.localId = localId
        self.builtinExerciseCode = builtinExerciseCode
        self.customExerciseId = customExerciseId
        self.exerciseName = exerciseName
        self.primaryMuscle = primaryMuscle
        self.orderIndex = orderIndex
        self.note = note
        self.sets = sets
    }
}

/// 一个动作下的单组记录（聚合子节点，不单独同步）。重量绝不自动预填（spec 约束）。
@Model
final class WorkoutSet {
    @Attribute(.unique) var localId: UUID
    var setIndex: Int
    var weightKg: Double?
    var reps: Int?
    var completed: Bool
    var note: String?

    var exercise: WorkoutExercise?

    init(
        localId: UUID = UUID(),
        setIndex: Int,
        weightKg: Double? = nil,
        reps: Int? = nil,
        completed: Bool = false,
        note: String? = nil
    ) {
        self.localId = localId
        self.setIndex = setIndex
        self.weightKg = weightKg
        self.reps = reps
        self.completed = completed
        self.note = note
    }
}
