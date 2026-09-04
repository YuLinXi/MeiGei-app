import Foundation
import SwiftData

/// 勋章授予记录（存根模型）。
///
/// 记录用户达成某项独立勋章的历史事实与关键数据快照。
/// 遵循 Day-1 铁律：徽章定义在客户端静态代码中维护，数据库仅保留轻量存根，支持点击反查当日具体训练。
@Model
final class BadgeGrant {
    /// 勋章唯一标识代码（如 "tonnage_100t", "strength_bw_bench_1_0"）
    @Attribute(.unique) var badgeCode: String
    /// 达成并解锁时间
    var unlockedAt: Date
    /// 触发该勋章解锁的 Workout.localId（可选，若关联的训练被删仍保留勋章）
    var workoutId: UUID?
    /// 达成时的度量快照数值（如当时的卧推重量、累计吨位、PR 总和等）
    var snapshotMetric: Double

    init(
        badgeCode: String,
        unlockedAt: Date = .now,
        workoutId: UUID? = nil,
        snapshotMetric: Double = 0
    ) {
        self.badgeCode = badgeCode
        self.unlockedAt = unlockedAt
        self.workoutId = workoutId
        self.snapshotMetric = snapshotMetric
    }

    /// 关联的静态勋章定义元数据
    var definition: BadgeDefinition? {
        BadgeDefinition.lookup(badgeCode)
    }
}
