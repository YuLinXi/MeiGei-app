import Foundation

/// 动作浏览的 **L1 部位**（动作库左栏部位轴）。取代旧 `MuscleGroup`（粗 8 类）。
/// rawValue 为中文，直接作为 `BuiltinExercise.category` 存储值（前后端一致）。
///
/// 单一解剖三级树：`L1 部位 → L2 肌肉（Muscle）→ L3 肌头/肌区（Muscle.heads，按需）`。
/// 解剖类（8）有 `muscles`（每块肌肉经 `regions` 与高亮叶级 `MuscleRegion` 对齐）；
/// 非解剖类（有氧/功能性/热身拉伸）无 `muscles`、不显高亮，改用 `browseSubcategories` 提供浏览下钻。
/// 浏览归位与高亮染色 **同源** 于动作的 `primaryRegions`（+ `subcategory` 肌头），不再维护两套脱节的树。
enum ExerciseCategory: String, CaseIterable, Identifiable, Codable, Hashable {
    // MARK: 解剖类（8）
    case chest      = "胸"
    case back       = "背"
    case shoulders  = "肩"
    case arms       = "手臂"
    case legs       = "腿"
    case glutes     = "臀"
    case core       = "核心"
    case neck       = "颈部"
    // MARK: 非解剖并行枝（3）
    case cardio     = "有氧"
    case functional = "功能性"
    case mobility   = "热身拉伸"

    var id: String { rawValue }

    /// 是否解剖类（有 L2 肌肉 / 高亮）。
    var isAnatomical: Bool { !muscles.isEmpty }

    /// **L2 肌肉层**（仅解剖类）。每块肌肉经 `regions` 对齐高亮叶级、经 `heads` 下挂 L3 肌头（可空）。
    /// 全部解剖类的 `regions` 并集恰好覆盖全部力量类 `MuscleRegion`，每个 region 归属唯一 L1/L2。
    var muscles: [Muscle] {
        switch self {
        case .chest:
            return [Muscle("胸大肌", [.chest], heads: ["上胸", "中下胸"])]
        case .back:
            return [Muscle("背阔肌", [.lats]),
                    Muscle("斜方肌", [.traps]),
                    Muscle("菱形肌", [.rhomboids]),
                    Muscle("竖脊肌", [.lowerBack])]
        case .shoulders:
            return [Muscle("三角肌", [.deltFront, .deltSide, .deltRear], heads: ["前束", "中束", "后束"])]
        case .arms:
            return [Muscle("肱二头肌", [.biceps]),
                    Muscle("肱三头肌", [.triceps]),
                    Muscle("前臂", [.forearms])]
        case .legs:
            return [Muscle("股四头肌", [.quads]),
                    Muscle("腘绳肌", [.hams]),
                    Muscle("内收肌", [.adductors]),
                    Muscle("小腿", [.calves])]
        case .glutes:
            return [Muscle("臀大肌", [.glutes]),
                    Muscle("臀中肌", [.gluteMed])]
        case .core:
            return [Muscle("腹直肌", [.abs], heads: ["上腹", "下腹"]),
                    Muscle("腹斜肌", [.obliques])]
        case .neck:
            return [Muscle("颈部肌", [.neck])]
        case .cardio, .functional, .mobility:
            return []
        }
    }

    /// 非解剖并行枝的浏览子类（功能性 5 / 热身拉伸 3 / 有氧 空）。
    /// 解剖类返回空（其下钻走 `muscles` 三级树）。功能性命名避开「核心」的「核心稳定」。
    var browseSubcategories: [String] {
        switch self {
        case .functional: return ["爆发奥举", "抗旋稳定", "髋臀激活", "负重搬运", "动态控制"]
        case .mobility:   return ["动态热身", "静态拉伸", "泡沫轴放松"]
        case .cardio:     return []          // 去噪后仅余稳态有氧，不再细分
        default:          return []
        }
    }

    /// 本 L1 覆盖的全部高亮叶级（`muscles` 各区并集）。非解剖类为空。
    var regions: [MuscleRegion] { muscles.flatMap(\.regions) }
}

/// **L2 肌肉**（解剖 L1 下的肌肉节点）。`regions` 对齐高亮叶级、`heads` 为 L3 肌头（按需，可空）。
struct Muscle: Hashable, Identifiable {
    let name: String
    let regions: [MuscleRegion]
    let heads: [String]
    var id: String { name }

    init(_ name: String, _ regions: [MuscleRegion], heads: [String] = []) {
        self.name = name
        self.regions = regions
        self.heads = heads
    }
    /// 是否有 L3 肌头（左栏据此决定 L2 可否再展开）。
    var hasHeads: Bool { !heads.isEmpty }
}

// MARK: - 树的反查与归一（浏览归位 + L1 收缩 + subcategory 重锚 的单一真源）

extension ExerciseCategory {
    /// 高亮叶级 `region` → 它归属的 (L1, L2 肌肉)。每个 region 归属唯一 L1/L2。
    static let regionOwner: [MuscleRegion: (category: ExerciseCategory, muscle: Muscle)] = {
        var map: [MuscleRegion: (ExerciseCategory, Muscle)] = [:]
        for cat in ExerciseCategory.allCases {
            for m in cat.muscles {
                for r in m.regions { map[r] = (cat, m) }
            }
        }
        return map
    }()

    /// 全部合法 L3 肌头（跨树唯一）：用于 `subcategory` 归一与校验。
    static let allHeads: Set<String> = {
        var s = Set<String>()
        for cat in ExerciseCategory.allCases { for m in cat.muscles { s.formUnion(m.heads) } }
        return s
    }()

    /// 旧 L1（15 类）→ 新 L1（11 类）收缩映射：单块肌肉冒充父级者降为某 L1 的 L2。
    /// `二头/三头/前臂 → 手臂`、`小腿 → 腿`、`斜方肌 → 背`；其余原样。
    static func collapseL1(_ raw: String) -> String {
        switch raw {
        case "二头", "三头", "前臂": return "手臂"
        case "小腿":               return "腿"
        case "斜方肌":             return "背"
        default:                   return raw
        }
    }

    /// 旧 L1（被收缩的单肌父级）→ 其对应的高亮区（用于给无 regionData 的导入条派生 L2）。
    static func regionForCollapsedL1(_ raw: String) -> MuscleRegion? {
        switch raw {
        case "二头":   return .biceps
        case "三头":   return .triceps
        case "前臂":   return .forearms
        case "小腿":   return .calves
        case "斜方肌": return .traps
        default:       return nil
        }
    }

    /// 旧 subcategory（部分实为肌肉/肌头级）→ 它精确指向的高亮区。
    /// 用于：① 给无 regionData 的导入条派生 L2/高亮；② 精修 curated 粗 regionData（中束/中背/臀中肌）。
    static func regionForSubcategory(_ sub: String) -> MuscleRegion? {
        switch sub {
        case "上胸", "中下胸":     return .chest
        case "背阔":              return .lats
        case "中背":              return .rhomboids
        case "下背":              return .lowerBack
        case "前束":              return .deltFront
        case "中束":              return .deltSide
        case "后束":              return .deltRear
        case "股四头":            return .quads
        case "腘绳肌":            return .hams
        case "臀大肌":            return .glutes
        case "臀中肌":            return .gluteMed
        case "上腹", "下腹", "核心稳定": return .abs
        case "腹斜肌":            return .obliques
        default:                  return nil
        }
    }
}
