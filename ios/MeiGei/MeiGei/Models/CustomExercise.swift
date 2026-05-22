import Foundation
import SwiftData

/// 用户自定义动作（参与同步，对应后端 custom_exercise）。
@Model
final class CustomExercise: Syncable {
    @Attribute(.unique) var localId: UUID
    var serverId: UUID?
    var updatedAt: Date
    var deletedAt: Date?
    var version: Int
    var syncStatusRaw: String

    var name: String
    var primaryMuscle: String?
    var equipmentType: String?

    init(
        localId: UUID = UUID(),
        name: String,
        primaryMuscle: String? = nil,
        equipmentType: String? = nil,
        now: Date = .now
    ) {
        self.localId = localId
        self.serverId = nil
        self.updatedAt = now
        self.deletedAt = nil
        self.version = 0
        self.syncStatusRaw = SyncStatus.pendingCreate.rawValue
        self.name = name
        self.primaryMuscle = primaryMuscle
        self.equipmentType = equipmentType
    }
}
