import Foundation

/// 肌群高亮图的细分区域（16 区，男女共用）。
/// `rawValue` 直接作为高亮图资产（PDF imageset / SVG 图层）命名，渲染层零映射；
/// 与粗粒度 `MuscleGroup`（胸/背/肩… 8 类，仍用于动作库筛选与 historyKey）并存、互不替代。
enum MuscleRegion: String, CaseIterable, Identifiable, Codable, Hashable {
    case traps        // 斜方肌
    case deltFront    // 三角肌前束
    case deltRear     // 三角肌后束
    case chest        // 胸大肌
    case biceps       // 肱二头肌
    case triceps      // 肱三头肌
    case forearms     // 前臂
    case abs          // 腹直肌
    case obliques     // 腹外斜肌
    case lats         // 背阔肌
    case lowerBack    // 竖脊肌 / 下背
    case glutes       // 臀大肌
    case quads        // 股四头肌
    case adductors    // 内收肌
    case hams         // 腘绳肌
    case calves       // 小腿
    // 与解剖三级树对齐补齐的细分区（美术按 muscle-map-detailed-art 分批补绘，补绘前优雅回退父级）
    case deltSide     // 三角肌中束
    case rhomboids    // 菱形肌 / 中背
    case gluteMed     // 臀中肌
    case neck         // 颈部

    var id: String { rawValue }

    /// 中文显示名（目标肌群文案用）。
    var displayName: String {
        switch self {
        case .traps:      return "斜方肌"
        case .deltFront:  return "三角肌前束"
        case .deltRear:   return "三角肌后束"
        case .chest:      return "胸大肌"
        case .biceps:     return "肱二头肌"
        case .triceps:    return "肱三头肌"
        case .forearms:   return "前臂"
        case .abs:        return "腹直肌"
        case .obliques:   return "腹外斜肌"
        case .lats:       return "背阔肌"
        case .lowerBack:  return "竖脊肌"
        case .glutes:     return "臀大肌"
        case .quads:      return "股四头肌"
        case .adductors:  return "内收肌"
        case .hams:       return "腘绳肌"
        case .calves:     return "小腿"
        case .deltSide:   return "三角肌中束"
        case .rhomboids:  return "菱形肌"
        case .gluteMed:   return "臀中肌"
        case .neck:       return "颈部"
        }
    }

    /// 人体展示面。用于高亮图默认面选择（亮区更多的一侧）与正/背切换时的可见性。
    enum Side: String, Codable { case front, back, both }

    var side: Side {
        switch self {
        case .deltFront, .chest, .biceps, .abs, .obliques, .quads, .adductors:
            return .front
        case .deltRear, .triceps, .lats, .lowerBack, .glutes, .hams:
            return .back
        case .deltSide:
            return .both
        case .rhomboids:
            return .back
        case .gluteMed:
            return .back
        case .traps, .forearms, .calves, .neck:
            return .both
        }
    }
}
