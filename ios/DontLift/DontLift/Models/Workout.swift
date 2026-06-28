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
    /// 来源 Team 分享计划（软关联，不参与计划同步）。
    var sourceShareId: UUID?
    var sourceShareVersionId: UUID?
    var sourcePlanNameSnapshot: String?
    var title: String?
    var startedAt: Date
    /// 计时起点（仅本地，不入同步信封）：nil = 计时未启动（会话已创建、浏览中）；
    /// 非 nil = 计时已启动（完成第一组或手动「开始训练」），REC 与训练时长均以此为基准。
    var timerStartedAt: Date?
    var endedAt: Date?
    var note: String?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var exercises: [WorkoutExercise]

    init(
        localId: UUID = UUID(),
        planId: UUID? = nil,
        sourceShareId: UUID? = nil,
        sourceShareVersionId: UUID? = nil,
        sourcePlanNameSnapshot: String? = nil,
        title: String? = nil,
        startedAt: Date = .now,
        timerStartedAt: Date? = nil,
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
        self.sourceShareId = sourceShareId
        self.sourceShareVersionId = sourceShareVersionId
        self.sourcePlanNameSnapshot = sourcePlanNameSnapshot
        self.title = title
        self.startedAt = startedAt
        self.timerStartedAt = timerStartedAt
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
    /// 来源计划项 `PlanItem.itemId`（自适应回写的合并主键，design.md D3）。
    /// nil = 训练中临时新增、非来自计划的动作。SwiftData 轻量迁移：optional 默认 nil。
    var planItemId: UUID?

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
        planItemId: UUID? = nil,
        sets: [WorkoutSet] = []
    ) {
        self.localId = localId
        self.builtinExerciseCode = builtinExerciseCode
        self.customExerciseId = customExerciseId
        self.exerciseName = exerciseName
        self.primaryMuscle = primaryMuscle
        self.orderIndex = orderIndex
        self.note = note
        self.planItemId = planItemId
        self.sets = sets
    }
}

/// 组类型。当前仅 working/warmup；后续可 append dropset/failure 等，
/// 统计判据为 `!= .warmup`，新增「正式类」case 无需改统计代码。
enum WorkoutSetType: String, Codable, CaseIterable {
    case working   // 正式组
    case warmup    // 热身组
    // 预留：case dropset / case failure ...
}

/// 一个动作下的单组记录（聚合子节点，不单独同步）。新增组可由调用方按当前训练上下文预填重量/次数；
/// 未完成组不计入训练量/PR。
@Model
final class WorkoutSet {
    @Attribute(.unique) var localId: UUID
    var setIndex: Int
    var weightKg: Double?
    var reps: Int?
    var completed: Bool
    var note: String?
    /// 组类型 raw（默认 "working"）。SwiftData 轻量迁移：存储属性声明带默认值，旧本地记录读出即 working。
    var setTypeRaw: String = WorkoutSetType.working.rawValue

    var exercise: WorkoutExercise?

    init(
        localId: UUID = UUID(),
        setIndex: Int,
        weightKg: Double? = nil,
        reps: Int? = nil,
        completed: Bool = false,
        note: String? = nil,
        setType: WorkoutSetType = .working
    ) {
        self.localId = localId
        self.setIndex = setIndex
        self.weightKg = weightKg
        self.reps = reps
        self.completed = completed
        self.note = note
        self.setTypeRaw = setType.rawValue
    }
}

// 计算属性放 extension：避免 @Model 宏对类体内带 get/set 的计算属性注入访问器导致解析错。
extension WorkoutSet {
    /// 组类型枚举视图：get 未知值兜底 `.working`（跨版本安全），set 写回 raw。
    var setType: WorkoutSetType {
        get { WorkoutSetType(rawValue: setTypeRaw) ?? .working }
        set { setTypeRaw = newValue.rawValue }
    }

    /// 统计判据：正式组**且已完成**（`setType != .warmup && completed`）。
    /// 「非 warmup」使将来新增的正式类组类型自动计入；「completed」保证落值后未打勾的
    /// 预填残组不污染训练量/PR（design.md D2）。纯「热身/正式」展示判断应直接用 `setType`。
    var countsForStats: Bool { setType != .warmup && completed }
}

extension WorkoutExercise {
    /// 展示用排序：热身组吸顶（warmup 段在前），段内按 setIndex 稳定升序（design.md D4）。
    var displaySortedSets: [WorkoutSet] {
        sets.sorted {
            let lw = $0.setType == .warmup, rw = $1.setType == .warmup
            if lw != rw { return lw }      // warmup 段在前
            return $0.setIndex < $1.setIndex
        }
    }

    /// 上一**正式**组重量（按 setIndex 取最后一个正式组），用于「加一组」预填源（热身组不作预填）。
    var lastWorkingWeight: Double? {
        sets.filter { $0.setType != .warmup }.sorted { $0.setIndex < $1.setIndex }.last?.weightKg
    }

    /// 上一**正式**组的重量与次数，用于新增正式组时继承输入值（热身组不作预填源）。
    var lastWorkingSetValues: (weightKg: Double?, reps: Int?) {
        guard let last = sets.filter({ $0.setType != .warmup }).sorted(by: { $0.setIndex < $1.setIndex }).last else {
            return (nil, nil)
        }
        return (last.weightKg, last.reps)
    }

    /// 切换某组 working ⇄ warmup，并重排到对应段尾（赋最大 setIndex+1）。仅改模型，保存由调用方负责。
    func toggleSetType(_ set: WorkoutSet) {
        set.setType = (set.setType == .warmup) ? .working : .warmup
        set.setIndex = (sets.map(\.setIndex).max() ?? -1) + 1
    }
}
