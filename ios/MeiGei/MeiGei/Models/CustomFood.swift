import Foundation
import SwiftData

/// 自定义食材（参与同步，对应后端 custom_food）。
/// 标准库（~1500 条）随包 seed、只读，不在此模型内。
@Model
final class CustomFood: Syncable {
    @Attribute(.unique) var localId: UUID
    var serverId: UUID?
    var updatedAt: Date
    var deletedAt: Date?
    var version: Int
    var syncStatusRaw: String

    var name: String
    /// 来源标识：authority | personal。个人项不进标准库首屏（design.md D9）。
    var source: String
    /// 营养含量基准，如 "100g" / "1 份"。
    var unitBasis: String
    var kcal: Double?
    var proteinG: Double?
    var carbG: Double?
    var fatG: Double?
    var fiberG: Double?
    var sugarG: Double?
    var sodiumMg: Double?

    init(
        localId: UUID = UUID(),
        name: String,
        source: String = "personal",
        unitBasis: String = "100g",
        kcal: Double? = nil,
        proteinG: Double? = nil,
        carbG: Double? = nil,
        fatG: Double? = nil,
        fiberG: Double? = nil,
        sugarG: Double? = nil,
        sodiumMg: Double? = nil,
        now: Date = .now
    ) {
        self.localId = localId
        self.serverId = nil
        self.updatedAt = now
        self.deletedAt = nil
        self.version = 0
        self.syncStatusRaw = SyncStatus.pendingCreate.rawValue
        self.name = name
        self.source = source
        self.unitBasis = unitBasis
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbG = carbG
        self.fatG = fatG
        self.fiberG = fiberG
        self.sugarG = sugarG
        self.sodiumMg = sodiumMg
    }
}
