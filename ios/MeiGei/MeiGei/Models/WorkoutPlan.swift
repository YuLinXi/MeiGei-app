import Foundation
import SwiftData

/// 训练计划模板里的单个动作项。每项带稳定 `itemId`（design.md D5），
/// 供编辑、Fork、diff 时定位。整体以 jsonb 文档随计划读写。
struct PlanItem: Codable, Identifiable, Hashable {
    var itemId: UUID
    /// 内置动作 code 或自定义动作引用，二选一。
    var builtinExerciseCode: String?
    var customExerciseId: UUID?
    var exerciseName: String
    var orderIndex: Int
    var suggestedSets: Int?
    var suggestedReps: Int?
    var suggestedWeightKg: Double?

    var id: UUID { itemId }

    init(
        itemId: UUID = UUID(),
        builtinExerciseCode: String? = nil,
        customExerciseId: UUID? = nil,
        exerciseName: String,
        orderIndex: Int,
        suggestedSets: Int? = nil,
        suggestedReps: Int? = nil,
        suggestedWeightKg: Double? = nil
    ) {
        self.itemId = itemId
        self.builtinExerciseCode = builtinExerciseCode
        self.customExerciseId = customExerciseId
        self.exerciseName = exerciseName
        self.orderIndex = orderIndex
        self.suggestedSets = suggestedSets
        self.suggestedReps = suggestedReps
        self.suggestedWeightKg = suggestedWeightKg
    }
}

/// 训练计划模板（参与同步，对应后端 workout_plan，items 以 jsonb 整体存储）。
@Model
final class WorkoutPlan: Syncable {
    @Attribute(.unique) var localId: UUID
    var serverId: UUID?
    var updatedAt: Date
    var deletedAt: Date?
    var version: Int
    var syncStatusRaw: String

    var name: String
    var items: [PlanItem]
    /// Fork 来源软指针；原模板增删不影响副本。
    var forkedFrom: UUID?
    /// 发布到的 Team；nil 表示私有。
    var sharedToTeamId: UUID?

    init(
        localId: UUID = UUID(),
        name: String,
        items: [PlanItem] = [],
        forkedFrom: UUID? = nil,
        sharedToTeamId: UUID? = nil,
        now: Date = .now
    ) {
        self.localId = localId
        self.serverId = nil
        self.updatedAt = now
        self.deletedAt = nil
        self.version = 0
        self.syncStatusRaw = SyncStatus.pendingCreate.rawValue
        self.name = name
        self.items = items
        self.forkedFrom = forkedFrom
        self.sharedToTeamId = sharedToTeamId
    }
}
