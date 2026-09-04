import Foundation

/// 成就勋章大类
enum BadgeCategory: String, CaseIterable, Identifiable {
    case strength   // 力量与三大项俱乐部
    case tonnage    // 累计总吨位
    case career     // 纪律与生涯历程
    case feats      // 单次战役极限

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strength: return "力量与三大项"
        case .tonnage:  return "累计总吨位"
        case .career:   return "纪律与历程"
        case .feats:    return "单次战役极限"
        }
    }

    var subtitle: String {
        switch self {
        case .strength: return "体重倍数突破与三大项绝对力量俱乐部"
        case .tonnage:  return "日积月累托起的重工工程量化"
        case .career:   return "千锤百炼、日复一日的自律刻度"
        case .feats:    return "单场极限爆发与严格执行的巅峰战役"
        }
    }

    /// 勋章几何外形语义（圆型精密盘、八边形砝码、六角战术章、菱形锋芒章）
    var shapeStyleName: String {
        switch self {
        case .strength: return "circle"
        case .tonnage:  return "octagon"
        case .career:   return "hexagon"
        case .feats:    return "diamond"
        }
    }
}

/// 24 枚独立成就勋章静态元数据
struct BadgeDefinition: Identifiable, Equatable, Hashable {
    let code: String
    let name: String
    let category: BadgeCategory
    let requirementDescription: String
    let targetValue: Double
    let unit: String
    let iconSystemName: String
    let orderIndex: Int

    var id: String { code }

    // MARK: - 全量 24 枚勋章清单定义

    static let all: [BadgeDefinition] = [
        // 一、力量与三大项俱乐部 (9 枚)
        BadgeDefinition(
            code: "strength_bw_bench_1_0",
            name: "破阵",
            category: .strength,
            requirementDescription: "杠铃卧推单组最高重量 ≥ 1.0x 体重",
            targetValue: 1.0,
            unit: "x BW",
            iconSystemName: "figure.strengthtraining.traditional",
            orderIndex: 1
        ),
        BadgeDefinition(
            code: "strength_bw_squat_1_5",
            name: "撼地",
            category: .strength,
            requirementDescription: "杠铃深蹲单组最高重量 ≥ 1.5x 体重",
            targetValue: 1.5,
            unit: "x BW",
            iconSystemName: "figure.cross.training",
            orderIndex: 2
        ),
        BadgeDefinition(
            code: "strength_bw_deadlift_2_0",
            name: "拔山",
            category: .strength,
            requirementDescription: "杠铃硬拉单组最高重量 ≥ 2.0x 体重",
            targetValue: 2.0,
            unit: "x BW",
            iconSystemName: "figure.core.training",
            orderIndex: 3
        ),
        BadgeDefinition(
            code: "strength_bw_bench_1_5",
            name: "铁穹",
            category: .strength,
            requirementDescription: "杠铃卧推单组最高重量 ≥ 1.5x 体重",
            targetValue: 1.5,
            unit: "x BW",
            iconSystemName: "shield.checkered",
            orderIndex: 4
        ),
        BadgeDefinition(
            code: "strength_bw_squat_2_0",
            name: "双倍重力",
            category: .strength,
            requirementDescription: "杠铃深蹲单组最高重量 ≥ 2.0x 体重",
            targetValue: 2.0,
            unit: "x BW",
            iconSystemName: "scalemass.fill",
            orderIndex: 5
        ),
        BadgeDefinition(
            code: "strength_bw_deadlift_2_5",
            name: "泰坦之握",
            category: .strength,
            requirementDescription: "杠铃硬拉单组最高重量 ≥ 2.5x 体重",
            targetValue: 2.5,
            unit: "x BW",
            iconSystemName: "lock.shield.fill",
            orderIndex: 6
        ),
        BadgeDefinition(
            code: "strength_big3_total_300",
            name: "300 俱乐部",
            category: .strength,
            requirementDescription: "杠铃三大项（深蹲+卧推+硬拉）历史 PR 总和 ≥ 300 kg",
            targetValue: 300,
            unit: "kg",
            iconSystemName: "crown",
            orderIndex: 7
        ),
        BadgeDefinition(
            code: "strength_big3_total_400",
            name: "400 俱乐部",
            category: .strength,
            requirementDescription: "杠铃三大项（深蹲+卧推+硬拉）历史 PR 总和 ≥ 400 kg",
            targetValue: 400,
            unit: "kg",
            iconSystemName: "crown.fill",
            orderIndex: 8
        ),
        BadgeDefinition(
            code: "strength_big3_total_500",
            name: "500 俱乐部",
            category: .strength,
            requirementDescription: "杠铃三大项（深蹲+卧推+硬拉）历史 PR 总和 ≥ 500 kg",
            targetValue: 500,
            unit: "kg",
            iconSystemName: "trophy.fill",
            orderIndex: 9
        ),

        // 二、累计总吨位 (5 枚)
        BadgeDefinition(
            code: "tonnage_10t",
            name: "初辟",
            category: .tonnage,
            requirementDescription: "生涯累计总训练量达到 10,000 kg",
            targetValue: 10_000,
            unit: "kg",
            iconSystemName: "cube.fill",
            orderIndex: 10
        ),
        BadgeDefinition(
            code: "tonnage_50t",
            name: "战车",
            category: .tonnage,
            requirementDescription: "生涯累计总训练量达到 50,000 kg",
            targetValue: 50_000,
            unit: "kg",
            iconSystemName: "box.truck.fill",
            orderIndex: 11
        ),
        BadgeDefinition(
            code: "tonnage_100t",
            name: "巨阙",
            category: .tonnage,
            requirementDescription: "生涯累计总训练量达到 100,000 kg",
            targetValue: 100_000,
            unit: "kg",
            iconSystemName: "hammer.fill",
            orderIndex: 12
        ),
        BadgeDefinition(
            code: "tonnage_500t",
            name: "磐石",
            category: .tonnage,
            requirementDescription: "生涯累计总训练量达到 500,000 kg",
            targetValue: 500_000,
            unit: "kg",
            iconSystemName: "mountain.2.fill",
            orderIndex: 13
        ),
        BadgeDefinition(
            code: "tonnage_1000t",
            name: "千吨引力",
            category: .tonnage,
            requirementDescription: "生涯累计总训练量达到 1,000,000 kg",
            targetValue: 1_000_000,
            unit: "kg",
            iconSystemName: "globe.asia.australia.fill",
            orderIndex: 14
        ),

        // 三、纪律与生涯历程 (5 枚)
        BadgeDefinition(
            code: "career_first_workout",
            name: "破晓",
            category: .career,
            requirementDescription: "完成生涯第 1 次有效训练记录",
            targetValue: 1,
            unit: "次",
            iconSystemName: "sunrise.fill",
            orderIndex: 15
        ),
        BadgeDefinition(
            code: "career_10_workouts",
            name: "习惯之始",
            category: .career,
            requirementDescription: "完成生涯累计第 10 次训练",
            targetValue: 10,
            unit: "次",
            iconSystemName: "flame.fill",
            orderIndex: 16
        ),
        BadgeDefinition(
            code: "career_50_workouts",
            name: "渐入佳境",
            category: .career,
            requirementDescription: "完成生涯累计第 50 次训练",
            targetValue: 50,
            unit: "次",
            iconSystemName: "gearshape.2.fill",
            orderIndex: 17
        ),
        BadgeDefinition(
            code: "career_100_workouts",
            name: "百炼成钢",
            category: .career,
            requirementDescription: "完成生涯累计第 100 次训练",
            targetValue: 100,
            unit: "次",
            iconSystemName: "shield.fill",
            orderIndex: 18
        ),
        BadgeDefinition(
            code: "career_300_workouts",
            name: "千锤之躯",
            category: .career,
            requirementDescription: "完成生涯累计第 300 次训练",
            targetValue: 300,
            unit: "次",
            iconSystemName: "medal.fill",
            orderIndex: 19
        ),

        // 四、单次战役极限 (5 枚)
        BadgeDefinition(
            code: "feat_volume_10t",
            name: "单场万吨",
            category: .feats,
            requirementDescription: "单次训练总训练量突破 10,000 kg",
            targetValue: 10_000,
            unit: "kg",
            iconSystemName: "bolt.horizontal.fill",
            orderIndex: 20
        ),
        BadgeDefinition(
            code: "feat_volume_20t",
            name: "力竭深渊",
            category: .feats,
            requirementDescription: "单次训练总训练量突破 20,000 kg",
            targetValue: 20_000,
            unit: "kg",
            iconSystemName: "bolt.fill",
            orderIndex: 21
        ),
        BadgeDefinition(
            code: "feat_triple_pr",
            name: "势如破竹",
            category: .feats,
            requirementDescription: "单次训练中同时刷新 ≥ 3 项动作的历史最高 PR",
            targetValue: 3,
            unit: "项",
            iconSystemName: "arrow.up.forward.circle.fill",
            orderIndex: 22
        ),
        BadgeDefinition(
            code: "feat_dense_sets",
            name: "铁血容量",
            category: .feats,
            requirementDescription: "单次训练完成正式组数量 ≥ 25 组",
            targetValue: 25,
            unit: "组",
            iconSystemName: "square.grid.3x3.fill",
            orderIndex: 23
        ),
        BadgeDefinition(
            code: "feat_perfect_plan",
            name: "严丝合缝",
            category: .feats,
            requirementDescription: "100% 严格执行计划内所有动作与预定组数",
            targetValue: 100,
            unit: "%",
            iconSystemName: "checkmark.seal.fill",
            orderIndex: 24
        )
    ]

    private static let byCode: [String: BadgeDefinition] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.code, $0) }
    )

    static func lookup(_ code: String) -> BadgeDefinition? {
        byCode[code]
    }

    static func badges(in category: BadgeCategory) -> [BadgeDefinition] {
        all.filter { $0.category == category }
            .sorted { $0.orderIndex < $1.orderIndex }
    }
}
