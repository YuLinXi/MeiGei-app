//
//  ExerciseTaxonomyTests.swift
//  DontLiftTests
//
//  动作分类法与内置动作数据契约（change exercise-library-taxonomy-import）：
//  ExerciseCategory 两级肌群 + 子分类、EquipmentType 扩展、全库 code 唯一、
//  非力量类无高亮、子分类归属合法。
//

import Testing
@testable import DontLift

struct ExerciseTaxonomyTests {

    // MARK: 1.6 分类枚举契约

    @Test func categoryRawValuesUnique() {
        let raws = ExerciseCategory.allCases.map(\.rawValue)
        #expect(Set(raws).count == raws.count)
    }

    /// 力量类父级的 region 并集恰好覆盖 16 个 MuscleRegion，且每个 region 归属唯一父级（分区）。
    @Test func regionsPartitionAll16() {
        var seen: [MuscleRegion] = []
        for c in ExerciseCategory.allCases { seen.append(contentsOf: c.regions) }
        #expect(Set(seen).count == 16)
        #expect(seen.count == 16)                       // 无重复归属
        #expect(Set(seen) == Set(MuscleRegion.allCases))
    }

    /// 非肌群父级（颈部/功能性/有氧/热身拉伸）region 为空。
    @Test func nonMuscleCategoriesHaveNoRegions() {
        for c in [ExerciseCategory.neck, .functional, .cardio, .mobility] {
            #expect(c.regions.isEmpty)
        }
    }

    @Test func equipmentRawValuesUnique() {
        let raws = EquipmentType.allCases.map(\.rawValue)
        #expect(Set(raws).count == raws.count)
        #expect(raws.contains("史密斯") && raws.contains("悍马机") && raws.contains("弹力带") && raws.contains("悬挂"))
    }

    /// 每个父级的子分类：父级内无重复；hasSubcategories 与清单一致。
    @Test func subcategoriesValidPerCategory() {
        for c in ExerciseCategory.allCases {
            let subs = c.subcategories
            #expect(Set(subs).count == subs.count)
            #expect(c.hasSubcategories == !subs.isEmpty)
        }
        #expect(ExerciseCategory.chest.subcategories == ["上胸", "中下胸"])
    }

    // MARK: 2.3 / 3.4 内置动作数据契约

    /// 全库（curated 153 + imported）code 唯一——防 historyKey 碰撞。
    @Test func allCodesUnique() {
        let codes = BuiltinExercise.starter.map(\.code)
        #expect(Set(codes).count == codes.count)
    }

    /// 每条动作的 category / equipmentType 命中合法枚举值。
    @Test func everyExerciseHasValidCategoryAndEquipment() {
        let cats = Set(ExerciseCategory.allCases.map(\.rawValue))
        let equips = Set(EquipmentType.allCases.map(\.rawValue))
        for ex in BuiltinExercise.starter {
            #expect(cats.contains(ex.category), "非法 category: \(ex.code) \(ex.category)")
            #expect(equips.contains(ex.equipmentType), "非法 equipment: \(ex.code) \(ex.equipmentType)")
        }
    }

    /// 非空 subcategory 必属其 category 的允许子分类清单。
    @Test func subcategoryBelongsToParent() {
        for ex in BuiltinExercise.starter {
            guard let sub = ex.subcategory, let c = ExerciseCategory(rawValue: ex.category) else { continue }
            #expect(c.subcategories.contains(sub), "子分类越界: \(ex.code) \(ex.category)/\(sub)")
        }
    }

    /// 老精选 code 仍在（防迁移误删/改名导致历史断裂的回归哨兵）。
    @Test func curatedAnchorsPresent() {
        let codes = Set(BuiltinExercise.starter.map(\.code))
        for anchor in ["BB_BENCH_PRESS", "BB_SQUAT", "DEADLIFT", "PULL_UP", "HIP_THRUST", "PLANK"] {
            #expect(codes.contains(anchor), "缺失精选 code: \(anchor)")
        }
    }

    /// 纯导入品类（有氧/热身拉伸/颈部）不带高亮 region（长尾未回填 → 高亮自动隐藏）。
    @Test func cardioAndMobilityHaveNoRegions() {
        for ex in BuiltinExercise.starter where ["有氧", "热身拉伸", "颈部"].contains(ex.category) {
            #expect(ex.primaryRegions.isEmpty, "非力量动作不应带 region: \(ex.code)")
        }
    }

    /// 库规模合理（curated 153 + 导入数百）。
    @Test func libraryHasExpectedScale() {
        #expect(BuiltinExercise.starter.count >= 1000)
    }
}
