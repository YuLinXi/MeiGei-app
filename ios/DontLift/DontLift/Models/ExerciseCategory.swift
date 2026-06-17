import Foundation

/// 动作浏览父级分类（动作库左栏部位轴）。取代旧 `MuscleGroup`（粗 8 类）。
/// rawValue 为中文，直接作为 `BuiltinExercise.category` 存储值（前后端一致）。
///
/// 两级肌群结构：父级（本枚举）→ 高亮叶级（`MuscleRegion`）。
/// 力量类父级经 `regions` 映射到若干 `MuscleRegion`；非肌群类（颈部/功能性/有氧/热身拉伸）映射为空、不显高亮。
/// 部分父级再下挂第三层「子分类」（`subcategories`），落在 `BuiltinExercise.subcategory` 上。
enum ExerciseCategory: String, CaseIterable, Identifiable, Codable, Hashable {
    case chest      = "胸"
    case back       = "背"
    case shoulders  = "肩"
    case traps      = "斜方肌"
    case biceps     = "二头"
    case triceps    = "三头"
    case forearms   = "前臂"
    case legs       = "腿"
    case calves     = "小腿"
    case glutes     = "臀"
    case core       = "核心"
    case neck       = "颈部"
    case functional = "功能性"
    case cardio     = "有氧"
    case mobility   = "热身拉伸"

    var id: String { rawValue }

    /// 浏览父级 → 高亮叶级 `MuscleRegion`（父子归属）。
    /// 力量类有子级；非肌群类返回空（动作高亮图隐藏）。
    /// 全部力量类的并集恰好覆盖 16 个 `MuscleRegion`，每个 region 归属唯一父级。
    var regions: [MuscleRegion] {
        switch self {
        case .chest:      return [.chest]
        case .back:       return [.lats, .lowerBack]
        case .shoulders:  return [.deltFront, .deltRear]
        case .traps:      return [.traps]
        case .biceps:     return [.biceps]
        case .triceps:    return [.triceps]
        case .forearms:   return [.forearms]
        case .legs:       return [.quads, .hams, .adductors]
        case .calves:     return [.calves]
        case .glutes:     return [.glutes]
        case .core:       return [.abs, .obliques]
        case .neck, .functional, .cardio, .mobility:
            return []
        }
    }

    /// 第三层子分类清单（父级作用域内有效，可为空=该父级不细分）。
    /// 经 1092 条训记动作覆盖校验定稿（design D7）；末位子类为「其余全归此」兜底。
    var subcategories: [String] {
        switch self {
        case .chest:     return ["上胸", "中下胸"]
        case .back:      return ["背阔", "中背", "下背"]
        case .shoulders: return ["前束", "中束", "后束"]
        case .legs:      return ["股四头", "腘绳肌"]
        case .glutes:    return ["臀大肌", "臀中肌"]
        case .core:      return ["上腹", "下腹", "腹斜肌", "核心稳定"]
        case .cardio:    return ["稳态有氧", "间歇·Tabata"]
        case .mobility:  return ["动态热身", "静态拉伸", "泡沫轴放松"]
        case .traps, .biceps, .triceps, .forearms, .calves, .neck, .functional:
            return []
        }
    }

    /// 是否有子分类（动作库左栏据此决定可否展开二级）。
    var hasSubcategories: Bool { !subcategories.isEmpty }
}
