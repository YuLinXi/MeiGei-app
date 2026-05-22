import Foundation
import SwiftData

/// 餐次。rawValue 为展示用中文，order 控制排序。
enum MealType: String, CaseIterable, Identifiable, Codable {
    case breakfast = "早餐"
    case lunch = "午餐"
    case dinner = "晚餐"
    case snack = "加餐"

    var id: String { rawValue }
    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    var systemImage: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch: return "sun.max"
        case .dinner: return "sunset"
        case .snack: return "takeoutbag.and.cup.and.straw"
        }
    }
}

/// 一日七项营养素合计（用于当日累计与目标对比）。
struct NutritionTotals {
    var kcal = 0.0
    var proteinG = 0.0
    var carbG = 0.0
    var fatG = 0.0
    var fiberG = 0.0
    var sugarG = 0.0
    var sodiumMg = 0.0

    static func + (lhs: NutritionTotals, rhs: NutritionTotals) -> NutritionTotals {
        NutritionTotals(kcal: lhs.kcal + rhs.kcal, proteinG: lhs.proteinG + rhs.proteinG,
                        carbG: lhs.carbG + rhs.carbG, fatG: lhs.fatG + rhs.fatG,
                        fiberG: lhs.fiberG + rhs.fiberG, sugarG: lhs.sugarG + rhs.sugarG,
                        sodiumMg: lhs.sodiumMg + rhs.sodiumMg)
    }
}

/// 饮食日记条目（本地存储）。
///
/// 范围说明：MVP 后端无饮食日记表（tasks 仅 4.3 自定义食材入云同步），
/// 故饮食日记仅本地 SwiftData 持久化，不接入 SyncEngine。
/// 营养素以每 100g 快照存储，记录时连同分量 `grams` 落地，
/// 避免事后改动食材库导致历史记录被追溯改写（单一真相为「记录当时」）。
@Model
final class FoodEntry {
    @Attribute(.unique) var localId: UUID
    /// 所属自然日（本地 0 点），用于按天聚合与「复制昨天」。
    var dayStart: Date
    var mealRaw: String
    var foodName: String
    /// 来源标识：standard | personal。
    var source: String
    /// 实际食用克数。
    var grams: Double
    var kcalPer100: Double
    var proteinPer100: Double
    var carbPer100: Double
    var fatPer100: Double
    var fiberPer100: Double
    var sugarPer100: Double
    var sodiumPer100: Double
    var createdAt: Date

    init(
        localId: UUID = UUID(),
        dayStart: Date,
        meal: MealType,
        foodName: String,
        source: String,
        grams: Double,
        kcalPer100: Double,
        proteinPer100: Double,
        carbPer100: Double,
        fatPer100: Double,
        fiberPer100: Double,
        sugarPer100: Double,
        sodiumPer100: Double,
        createdAt: Date = .now
    ) {
        self.localId = localId
        self.dayStart = dayStart
        self.mealRaw = meal.rawValue
        self.foodName = foodName
        self.source = source
        self.grams = grams
        self.kcalPer100 = kcalPer100
        self.proteinPer100 = proteinPer100
        self.carbPer100 = carbPer100
        self.fatPer100 = fatPer100
        self.fiberPer100 = fiberPer100
        self.sugarPer100 = sugarPer100
        self.sodiumPer100 = sodiumPer100
        self.createdAt = createdAt
    }

    var meal: MealType { MealType(rawValue: mealRaw) ?? .snack }

    /// 按分量换算后的实际营养。
    var totals: NutritionTotals {
        let f = grams / 100
        return NutritionTotals(kcal: kcalPer100 * f, proteinG: proteinPer100 * f,
                               carbG: carbPer100 * f, fatG: fatPer100 * f,
                               fiberG: fiberPer100 * f, sugarG: sugarPer100 * f,
                               sodiumMg: sodiumPer100 * f)
    }
}
