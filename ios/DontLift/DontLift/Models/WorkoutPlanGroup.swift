import Foundation
import SwiftData

/// 训练计划分组（参与同步，对应后端 workout_plan_group）。
@Model
final class WorkoutPlanGroup: Syncable {
    @Attribute(.unique) var localId: UUID
    var serverId: UUID?
    var updatedAt: Date
    var deletedAt: Date?
    var version: Int
    var syncStatusRaw: String

    var name: String
    /// 分组排序值，升序排列；同值时列表按 updatedAt 兜底。
    var sortOrder: Int = 0

    init(
        localId: UUID = UUID(),
        name: String,
        sortOrder: Int = 0,
        now: Date = .now
    ) {
        self.localId = localId
        self.serverId = nil
        self.updatedAt = now
        self.deletedAt = nil
        self.version = 0
        self.syncStatusRaw = SyncStatus.pendingCreate.rawValue
        self.name = name
        self.sortOrder = sortOrder
    }
}
