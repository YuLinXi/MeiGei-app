import Foundation

/// 食材分类（用于浏览与筛选）。rawValue 为展示用中文。
enum FoodCategory: String, CaseIterable, Identifiable, Codable {
    case staple = "主食"
    case meat = "肉类"
    case seafood = "水产"
    case egg = "蛋类"
    case dairy = "乳制品"
    case bean = "豆类"
    case vegetable = "蔬菜"
    case fruit = "水果"
    case nut = "坚果"
    case beverage = "饮品"
    case snack = "零食"
    case condiment = "调味"

    var id: String { rawValue }
}

/// 内置标准食材（只读，随包发布，离线可用）。
///
/// 营养素均以 `unitBasis`（默认每 100g）为基准给出 7 项含量。
/// 来源：本项目从公开来源逐条采集单条营养事实并自行编排（design.md D9），
/// 标识为「标准库」而非官方/权威；每条以 `sourceNote` 记录来源备查。
///
/// 注意：当前 `standard` 为代表性子集（覆盖各类别的占位样本）。
/// 任务 4.1 的完整 ~1500 条需由数据工程逐条采集来源后补齐，
/// 不整表照搬受著作权保护的成分表汇编、不使用未授权第三方转录。
struct BuiltinFood: Identifiable, Hashable, Codable {
    let code: String
    let name: String
    let category: String
    /// 营养含量基准，标准库统一为 "100g"。
    let unitBasis: String
    let kcal: Double
    let proteinG: Double
    let carbG: Double
    let fatG: Double
    let fiberG: Double
    let sugarG: Double
    let sodiumMg: Double
    /// 来源备查（采集出处），合规要求逐条记录（design.md D9）。
    let sourceNote: String

    var id: String { code }
}

extension BuiltinFood {
    /// 标准库基准固定为每 100g。
    static let basisGrams: Double = 100

    /// 代表性子集（占位，待 4.1 数据任务补齐至 ~1500 条）。
    /// 营养值为每 100g 的近似常识值，仅作开发期占位；上线前由数据任务逐条核定并补来源。
    static let standard: [BuiltinFood] = [
        // 主食
        food("ST_RICE_COOKED", "米饭(熟)", .staple, 116, 2.6, 25.9, 0.3, 0.3, 0, 2),
        food("ST_RICE_RAW", "大米(生)", .staple, 346, 7.4, 77.9, 0.8, 0.7, 0, 4),
        food("ST_NOODLE_COOKED", "面条(煮)", .staple, 110, 4.5, 22.0, 0.6, 1.0, 0, 90),
        food("ST_STEAMED_BUN", "馒头", .staple, 223, 7.0, 47.0, 1.1, 1.3, 1.0, 165),
        food("ST_BREAD", "面包", .staple, 312, 8.3, 58.6, 5.1, 2.7, 6.0, 230),
        food("ST_OAT", "燕麦片", .staple, 367, 15.0, 61.0, 7.0, 10.0, 1.0, 3),
        food("ST_SWEET_POTATO", "红薯", .staple, 99, 1.1, 24.7, 0.2, 1.6, 5.0, 28),
        food("ST_POTATO", "土豆", .staple, 81, 2.6, 17.8, 0.2, 1.1, 0.8, 5),
        // 肉类
        food("MT_CHICKEN_BREAST", "鸡胸肉", .meat, 118, 24.6, 0.6, 1.9, 0, 0, 63),
        food("MT_CHICKEN_LEG", "鸡腿", .meat, 181, 16.0, 0, 13.0, 0, 0, 70),
        food("MT_BEEF_LEAN", "牛肉(瘦)", .meat, 125, 20.2, 1.2, 4.2, 0, 0, 53),
        food("MT_PORK_LEAN", "猪肉(瘦)", .meat, 143, 20.3, 1.5, 6.2, 0, 0, 57),
        food("MT_PORK_BELLY", "五花肉", .meat, 508, 7.7, 0, 53.0, 0, 0, 47),
        food("MT_LAMB", "羊肉(瘦)", .meat, 118, 20.5, 0.2, 3.9, 0, 0, 69),
        // 水产
        food("SF_SHRIMP", "虾仁", .seafood, 87, 18.2, 1.0, 0.7, 0, 0, 165),
        food("SF_SALMON", "三文鱼", .seafood, 139, 20.0, 0, 6.3, 0, 0, 59),
        food("SF_BASA", "巴沙鱼", .seafood, 90, 18.0, 0, 1.5, 0, 0, 60),
        food("SF_CRUCIAN", "鲫鱼", .seafood, 108, 17.1, 0, 2.7, 0, 0, 41),
        // 蛋类
        food("EG_EGG_WHOLE", "鸡蛋", .egg, 144, 13.3, 2.8, 8.8, 0, 0, 132),
        food("EG_EGG_WHITE", "蛋清", .egg, 60, 11.6, 3.1, 0.1, 0, 0, 166),
        // 乳制品
        food("DA_MILK", "牛奶", .dairy, 54, 3.0, 3.4, 3.2, 0, 3.4, 37),
        food("DA_YOGURT", "酸奶", .dairy, 72, 2.5, 9.3, 2.7, 0, 9.0, 39),
        food("DA_CHEESE", "奶酪", .dairy, 328, 25.7, 3.5, 23.5, 0, 0, 584),
        // 豆类
        food("BN_TOFU", "豆腐", .bean, 82, 8.1, 4.2, 3.7, 0.4, 0, 7),
        food("BN_SOY_MILK", "豆浆", .bean, 31, 3.0, 1.2, 1.6, 1.1, 0, 3),
        food("BN_SOYBEAN", "黄豆", .bean, 390, 35.0, 34.2, 16.0, 15.5, 0, 2),
        // 蔬菜
        food("VG_BROCCOLI", "西兰花", .vegetable, 36, 4.1, 4.3, 0.6, 1.6, 1.5, 18),
        food("VG_SPINACH", "菠菜", .vegetable, 28, 2.6, 4.5, 0.3, 1.7, 0.4, 85),
        food("VG_CUCUMBER", "黄瓜", .vegetable, 16, 0.8, 2.9, 0.2, 0.5, 1.8, 5),
        food("VG_TOMATO", "番茄", .vegetable, 20, 0.9, 4.0, 0.2, 0.5, 2.6, 5),
        food("VG_LETTUCE", "生菜", .vegetable, 16, 1.4, 2.1, 0.3, 0.7, 1.0, 33),
        // 水果
        food("FR_APPLE", "苹果", .fruit, 54, 0.2, 13.5, 0.2, 1.2, 10.4, 1),
        food("FR_BANANA", "香蕉", .fruit, 93, 1.4, 22.0, 0.2, 1.2, 12.0, 1),
        food("FR_ORANGE", "橙子", .fruit, 48, 0.8, 11.1, 0.2, 0.6, 9.0, 1),
        food("FR_BLUEBERRY", "蓝莓", .fruit, 57, 0.7, 14.5, 0.3, 2.4, 10.0, 1),
        // 坚果
        food("NT_ALMOND", "杏仁", .nut, 578, 21.2, 21.6, 49.9, 12.5, 4.8, 1),
        food("NT_WALNUT", "核桃", .nut, 654, 15.2, 13.7, 65.2, 6.7, 2.6, 2),
        food("NT_PEANUT", "花生", .nut, 567, 25.8, 16.1, 49.2, 8.5, 4.7, 18),
        // 饮品
        food("BV_COLA", "可乐", .beverage, 43, 0, 10.6, 0, 0, 10.6, 4),
        food("BV_BLACK_COFFEE", "黑咖啡", .beverage, 2, 0.1, 0, 0, 0, 0, 5),
        // 调味
        food("CD_OLIVE_OIL", "橄榄油", .condiment, 899, 0, 0, 99.9, 0, 0, 0),
        food("CD_SUGAR", "白砂糖", .condiment, 400, 0, 99.9, 0, 0, 99.9, 0),
    ]

    private static func food(
        _ code: String, _ name: String, _ category: FoodCategory,
        _ kcal: Double, _ protein: Double, _ carb: Double, _ fat: Double,
        _ fiber: Double, _ sugar: Double, _ sodium: Double
    ) -> BuiltinFood {
        BuiltinFood(code: code, name: name, category: category.rawValue, unitBasis: "100g",
                    kcal: kcal, proteinG: protein, carbG: carb, fatG: fat,
                    fiberG: fiber, sugarG: sugar, sodiumMg: sodium,
                    sourceNote: "占位样本，待数据任务核定来源")
    }
}
