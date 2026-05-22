import Foundation
import SwiftData

/// 用户每日营养目标与计算资料（本地单例，不参与云同步）。
///
/// 资料用于 Mifflin-St Jeor 计算推荐值；推荐值写入 target* 字段后，
/// 用户可手动微调任一目标值（直接覆盖 target*，不回算资料）。
@Model
final class NutritionGoal {
    @Attribute(.unique) var id: UUID
    /// 是否已完成首次引导（决定是否弹引导）。
    var isConfigured: Bool

    // 计算资料
    var sexRaw: String
    var age: Int
    var heightCm: Double
    var weightKg: Double
    var activityRaw: String
    var goalRaw: String

    // 每日目标（可手动微调）
    var targetKcal: Double
    var targetProteinG: Double
    var targetCarbG: Double
    var targetFatG: Double

    var updatedAt: Date

    init(
        id: UUID = UUID(),
        isConfigured: Bool = false,
        sex: BioSex = .male,
        age: Int = 25,
        heightCm: Double = 170,
        weightKg: Double = 65,
        activity: ActivityLevel = .light,
        goal: FitnessGoal = .maintain,
        targets: DailyTargets = DailyTargets(kcal: 2000, proteinG: 120, carbG: 220, fatG: 60),
        updatedAt: Date = .now
    ) {
        self.id = id
        self.isConfigured = isConfigured
        self.sexRaw = sex.rawValue
        self.age = age
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activityRaw = activity.rawValue
        self.goalRaw = goal.rawValue
        self.targetKcal = targets.kcal
        self.targetProteinG = targets.proteinG
        self.targetCarbG = targets.carbG
        self.targetFatG = targets.fatG
        self.updatedAt = updatedAt
    }

    var sex: BioSex { BioSex(rawValue: sexRaw) ?? .male }
    var activity: ActivityLevel { ActivityLevel(rawValue: activityRaw) ?? .light }
    var goal: FitnessGoal { FitnessGoal(rawValue: goalRaw) ?? .maintain }

    var targets: DailyTargets {
        DailyTargets(kcal: targetKcal, proteinG: targetProteinG, carbG: targetCarbG, fatG: targetFatG)
    }

    /// 用引导资料重算并覆盖目标值。
    func applyRecommendation() {
        let r = NutritionMath.recommend(sex: sex, weightKg: weightKg, heightCm: heightCm,
                                        age: age, activity: activity, goal: goal)
        targetKcal = r.kcal
        targetProteinG = r.proteinG
        targetCarbG = r.carbG
        targetFatG = r.fatG
        updatedAt = .now
    }
}
