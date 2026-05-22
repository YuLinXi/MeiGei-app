import Foundation

/// 生理性别（仅用于 BMR 公式，非账户性别）。
enum BioSex: String, CaseIterable, Identifiable, Codable {
    case male = "男"
    case female = "女"
    var id: String { rawValue }
}

/// 活动量等级及其 TDEE 系数。
enum ActivityLevel: String, CaseIterable, Identifiable, Codable {
    case sedentary = "久坐"
    case light = "轻度活动"
    case moderate = "中度活动"
    case active = "高度活动"
    case veryActive = "极高活动"

    var id: String { rawValue }
    var factor: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }
    var hint: String {
        switch self {
        case .sedentary: return "几乎不运动"
        case .light: return "每周 1-3 次"
        case .moderate: return "每周 3-5 次"
        case .active: return "每周 6-7 次"
        case .veryActive: return "体力工作 / 每日高强度"
        }
    }
}

/// 健身目标，决定热量盈亏与宏量分配策略。
enum FitnessGoal: String, CaseIterable, Identifiable, Codable {
    case cut = "减脂"
    case maintain = "维持"
    case bulk = "增肌"
    var id: String { rawValue }
}

/// 每日营养目标（热量 + 三大宏量）。
struct DailyTargets: Equatable {
    var kcal: Double
    var proteinG: Double
    var carbG: Double
    var fatG: Double
}

/// 基于 Mifflin-St Jeor 的目标计算。
enum NutritionMath {
    /// Mifflin-St Jeor 基础代谢率（kcal/日）。
    static func bmr(sex: BioSex, weightKg: Double, heightCm: Double, age: Int) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return sex == .male ? base + 5 : base - 161
    }

    /// 每日总消耗 = BMR × 活动系数。
    static func tdee(bmr: Double, activity: ActivityLevel) -> Double {
        bmr * activity.factor
    }

    /// 根据资料推荐每日热量与三大宏量分配。
    ///
    /// 热量：减脂在 TDEE 基础上 -20%，增肌 +12%，维持不变。
    /// 蛋白质：按体重给量（减脂 2.0 / 增肌 1.8 / 维持 1.6 g·kg⁻¹）。
    /// 脂肪：占总热量 25%。碳水：扣除蛋白与脂肪后的剩余热量 ÷ 4。
    static func recommend(
        sex: BioSex, weightKg: Double, heightCm: Double, age: Int,
        activity: ActivityLevel, goal: FitnessGoal
    ) -> DailyTargets {
        let maintenance = tdee(bmr: bmr(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age),
                               activity: activity)
        let kcal: Double
        switch goal {
        case .cut: kcal = maintenance * 0.80
        case .maintain: kcal = maintenance
        case .bulk: kcal = maintenance * 1.12
        }
        let proteinPerKg: Double
        switch goal {
        case .cut: proteinPerKg = 2.0
        case .maintain: proteinPerKg = 1.6
        case .bulk: proteinPerKg = 1.8
        }
        let proteinG = (proteinPerKg * weightKg).rounded()
        let fatG = (kcal * 0.25 / 9).rounded()
        let remainingKcal = max(0, kcal - proteinG * 4 - fatG * 9)
        let carbG = (remainingKcal / 4).rounded()
        return DailyTargets(kcal: kcal.rounded(), proteinG: proteinG, carbG: carbG, fatG: fatG)
    }
}
