import Foundation

/// 选中食材的归一化结果（统一为每 100g 的 7 项营养），供记录日记复用。
struct FoodPick: Identifiable, Hashable {
    var name: String
    /// standard | personal
    var source: String
    var kcalPer100: Double
    var proteinPer100: Double
    var carbPer100: Double
    var fatPer100: Double
    var fiberPer100: Double
    var sugarPer100: Double
    var sodiumPer100: Double

    var id: String { source + ":" + name }

    init(builtin f: BuiltinFood) {
        name = f.name; source = "standard"
        kcalPer100 = f.kcal; proteinPer100 = f.proteinG; carbPer100 = f.carbG; fatPer100 = f.fatG
        fiberPer100 = f.fiberG; sugarPer100 = f.sugarG; sodiumPer100 = f.sodiumMg
    }

    init(custom f: CustomFood) {
        name = f.name; source = "personal"
        kcalPer100 = f.kcal ?? 0; proteinPer100 = f.proteinG ?? 0; carbPer100 = f.carbG ?? 0
        fatPer100 = f.fatG ?? 0; fiberPer100 = f.fiberG ?? 0; sugarPer100 = f.sugarG ?? 0
        sodiumPer100 = f.sodiumMg ?? 0
    }
}

/// 离线食材搜索：合并标准库 + 个人自定义，按名称匹配。
/// 标准库结果优先展示（design.md D9：个人项不进标准库首屏）。
func filterFoods(
    builtin: [BuiltinFood],
    custom: [CustomFood],
    query: String,
    category: FoodCategory?
) -> (builtin: [BuiltinFood], custom: [CustomFood]) {
    let q = query.trimmingCharacters(in: .whitespaces)
    func matchQuery(_ name: String) -> Bool { q.isEmpty || name.localizedCaseInsensitiveContains(q) }
    let b = builtin.filter { (category == nil || $0.category == category?.rawValue) && matchQuery($0.name) }
    let c = custom.filter { $0.deletedAt == nil && matchQuery($0.name) }
    return (b, c)
}

/// 数字格式化：最多 1 位小数、去掉无意义尾零。
func fmtNum(_ value: Double) -> String {
    if value.rounded() == value { return String(Int(value)) }
    return String(format: "%.1f", value)
}

extension Calendar {
    /// 给定日期所在自然日的 0 点（本地时区）。
    func dayStart(for date: Date) -> Date { startOfDay(for: date) }
}
