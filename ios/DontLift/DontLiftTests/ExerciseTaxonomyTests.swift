//
//  ExerciseTaxonomyTests.swift
//  DontLiftTests
//
//  单一解剖三级树（change exercise-library-experience-upgrade）：
//  L1 部位 11 → L2 肌肉 → L3 肌头；浏览与高亮同源；去噪后全库 code 唯一；
//  subcategory 重锚为合法 L3；curated code 冻结不变；中文模糊多词搜索。
//

import Testing
@testable import DontLift

struct ExerciseTaxonomyTests {

    // MARK: 1.6 三级树契约

    /// L1 恰为 11（解剖 8 + 非解剖 3），rawValue 唯一，且不含被收缩的旧单肌父级。
    @Test func l1IsElevenParts() {
        let raws = ExerciseCategory.allCases.map(\.rawValue)
        #expect(raws.count == 11)
        #expect(Set(raws).count == 11)
        for gone in ["二头", "三头", "前臂", "小腿", "斜方肌"] {
            #expect(!raws.contains(gone), "旧单肌父级不应作为 L1: \(gone)")
        }
        for must in ["胸","背","肩","手臂","腿","臀","核心","颈部","有氧","功能性","热身拉伸"] {
            #expect(raws.contains(must), "缺 L1: \(must)")
        }
    }

    /// 每个 region 归属唯一 L1/L2；全部解剖 L1 的 region 并集覆盖 20 区无重复。
    @Test func regionsPartitionTreeUniquely() {
        var seen: [MuscleRegion] = []
        for c in ExerciseCategory.allCases { seen.append(contentsOf: c.regions) }
        #expect(seen.count == 20)                       // 无重复归属
        #expect(Set(seen).count == 20)
        #expect(Set(seen) == Set(MuscleRegion.allCases))
        #expect(ExerciseCategory.regionOwner.count == 20)
    }

    /// 三级逐级归属合法：L2 属其 L1、L3 属其 L2，且各级名无重复。
    @Test func treeLevelsWellFormed() {
        for c in ExerciseCategory.allCases {
            let muscleNames = c.muscles.map(\.name)
            #expect(Set(muscleNames).count == muscleNames.count, "\(c.rawValue) L2 重名")
            for m in c.muscles {
                #expect(Set(m.heads).count == m.heads.count, "\(m.name) L3 重名")
            }
        }
        // 抽链校验：胸 → 胸大肌 → 上胸
        let chest = ExerciseCategory.chest
        #expect(chest.muscles.first?.name == "胸大肌")
        #expect(chest.muscles.first?.heads == ["上胸", "中下胸"])
    }

    /// L3 按需不强配：部分 L2 无肌头（如背阔肌/肱二头肌）。
    @Test func l3IsOptional() {
        let lats = ExerciseCategory.back.muscles.first { $0.name == "背阔肌" }
        #expect(lats?.heads.isEmpty == true)
        let delt = ExerciseCategory.shoulders.muscles.first { $0.name == "三角肌" }
        #expect(delt?.heads == ["前束", "中束", "后束"])
    }

    /// 展示层折叠单一中间肌肉层：胸/肩直接露出 L3，内部三级树不变。
    @Test func displayCollapsesSingleMuscleWithHeads() {
        #expect(ExerciseCategory.chest.collapsedBrowseMuscle?.name == "胸大肌")
        #expect(ExerciseCategory.shoulders.collapsedBrowseMuscle?.name == "三角肌")
        #expect(ExerciseCategory.back.collapsedBrowseMuscle == nil)
        #expect(ExerciseCategory.core.collapsedBrowseMuscle == nil)
        #expect(ExerciseCategory.neck.collapsedBrowseMuscle == nil)
    }

    /// 非解剖 L1（有氧/功能性/热身拉伸）无 region；功能性/热身拉伸有浏览子类，有氧无。
    @Test func nonAnatomicalParts() {
        for c in [ExerciseCategory.cardio, .functional, .mobility] {
            #expect(c.regions.isEmpty)
            #expect(!c.isAnatomical)
        }
        #expect(ExerciseCategory.functional.browseSubcategories.count == 5)
        #expect(ExerciseCategory.mobility.browseSubcategories.count == 3)
        #expect(ExerciseCategory.cardio.browseSubcategories.isEmpty)
        // 颈部为解剖 L1（有 neck 区）。
        #expect(ExerciseCategory.neck.isAnatomical)
    }

    @Test func equipmentRawValuesUnique() {
        let raws = EquipmentType.allCases.map(\.rawValue)
        #expect(Set(raws).count == raws.count)
        #expect(raws.contains("史密斯") && raws.contains("悍马机") && raws.contains("弹力带") && raws.contains("悬挂"))
    }

    // MARK: 2.3 内置动作数据契约

    /// 全库 code 唯一——防 historyKey 碰撞。
    @Test func allCodesUnique() {
        let codes = BuiltinExercise.starter.map(\.code)
        #expect(Set(codes).count == codes.count)
    }

    /// 每条 category 命中 11 个 L1、equipmentType 合法。
    @Test func everyExerciseHasValidL1AndEquipment() {
        let cats = Set(ExerciseCategory.allCases.map(\.rawValue))
        let equips = Set(EquipmentType.allCases.map(\.rawValue))
        for ex in BuiltinExercise.starter {
            #expect(cats.contains(ex.category), "非法 category: \(ex.code) \(ex.category)")
            #expect(equips.contains(ex.equipmentType), "非法 equipment: \(ex.code) \(ex.equipmentType)")
        }
    }

    /// 非空 subcategory 必属合法 L3 肌头 或 其 L1 的非解剖浏览子类。
    @Test func subcategoryIsValidL3OrBucket() {
        for ex in BuiltinExercise.starter {
            guard let sub = ex.subcategory, let c = ExerciseCategory(rawValue: ex.category) else { continue }
            let isHead = ExerciseCategory.allHeads.contains(sub)
            let isBucket = c.browseSubcategories.contains(sub)
            #expect(isHead || isBucket, "subcategory 越界: \(ex.code) \(ex.category)/\(sub)")
        }
    }

    @Test func mobilityExercisesHaveBrowsableSubcategories() {
        let allowed = Set(ExerciseCategory.mobility.browseSubcategories)
        for ex in BuiltinExercise.starter where ex.category == "热身拉伸" {
            #expect(ex.subcategory.map { allowed.contains($0) } == true, "热身拉伸缺少可浏览子类: \(ex.code)")
        }
    }

    @Test func kettlebellSwingUsesKettlebellEquipment() {
        let swing = BuiltinExercise.starter.first { $0.code == "KETTLEBELL_SWING" }
        #expect(swing?.equipmentType == "壶铃")
    }

    /// 浏览与高亮同源：命中 chest 区者归「胸 → 胸大肌」。
    @Test func browseHighlightSameSource() {
        let bench = BuiltinExercise.starter.first { $0.code == "BB_BENCH_PRESS" }!
        #expect(bench.category == "胸")
        let owner = bench.primaryRegions.compactMap { ExerciseCategory.regionOwner[$0] }.first
        #expect(owner?.category == .chest)
        #expect(owner?.muscle.name == "胸大肌")
    }

    /// L1 收缩落位：原 二头/三头 动作落「手臂」、斜方肌落「背」、小腿落「腿」。
    @Test func collapsedL1Landings() {
        func cat(_ code: String) -> String? { BuiltinExercise.starter.first { $0.code == code }?.category }
        #expect(cat("BB_CURL") == "手臂")            // 二头 → 手臂
        #expect(cat("TRICEP_PUSHDOWN") == "手臂")    // 三头 → 手臂
        #expect(cat("WRIST_CURL") == "手臂")         // 前臂 → 手臂
        #expect(cat("SHRUG_BB") == "背")             // 斜方肌 → 背
        #expect(cat("STANDING_CALF_RAISE") == "腿")  // 小腿 → 腿
    }

    /// curated code 集合仍作为旧库回滚/排序参考；V1 预置库只保留已确认动作。
    @Test func curatedCodesRemainAvailableForFallback() {
        #expect(BuiltinExercise.curatedCodes.count == 153)
        let codes = Set(BuiltinExercise.starter.map(\.code))
        for anchor in ["BB_BENCH_PRESS", "BB_SQUAT", "DEADLIFT", "PULL_UP", "HIP_THRUST", "PLANK"] {
            #expect(codes.contains(anchor), "缺失 V1 必留 code: \(anchor)")
        }
    }

    // MARK: 3.x 去噪契约

    /// 去噪后：无任何「（版本」字样；有氧不含「间歇·Tabata」。
    @Test func denoised() {
        for ex in BuiltinExercise.starter {
            #expect(!ex.name.contains("（版本"), "残留版本名: \(ex.code) \(ex.name)")
            #expect(!ex.name.contains("(版本"), "残留版本名: \(ex.code) \(ex.name)")
        }
        for ex in BuiltinExercise.starter where ex.category == "有氧" {
            #expect(ex.subcategory != "间歇·Tabata", "有氧仍含 Tabata: \(ex.code)")
        }
    }

    /// 有氧/热身拉伸无高亮 region（非力量动作）。
    @Test func cardioMobilityNoRegions() {
        for ex in BuiltinExercise.starter where ["有氧", "热身拉伸"].contains(ex.category) {
            #expect(ex.primaryRegions.isEmpty, "非力量动作不应带 region: \(ex.code)")
        }
    }

    @Test func tricepAndShoulderWarmupAdditions() {
        let byCode = Dictionary(uniqueKeysWithValues: BuiltinExercise.starter.map { ($0.code, $0) })

        #expect(byCode["TRICEP_KICKBACK"]?.name == "哑铃臂屈伸")
        #expect(byCode["TRICEP_KICKBACK"]?.primaryRegions == [.triceps])

        let singleArm = byCode["SINGLE_ARM_DB_TRICEP_EXT"]
        #expect(singleArm?.name == "单臂哑铃臂屈伸")
        #expect(singleArm?.category == "手臂")
        #expect(singleArm?.equipmentType == "哑铃")
        #expect(singleArm?.primaryRegions == [.triceps])

        let beckoningCat = byCode["SHOULDER_90_90_EXTERNAL_ROTATION"]
        #expect(beckoningCat?.name == "招财猫")
        #expect(beckoningCat?.category == "热身拉伸")
        #expect(beckoningCat?.subcategory == "动态热身")
        #expect(beckoningCat?.equipmentType == "自重")
        #expect(beckoningCat?.primaryRegions.isEmpty == true)

        let bandExternalRotation = byCode["BAND_SHOULDER_EXTERNAL_ROTATION"]
        #expect(bandExternalRotation?.name == "弹力带肩外旋")
        #expect(bandExternalRotation?.category == "热身拉伸")
        #expect(bandExternalRotation?.subcategory == "动态热身")
        #expect(bandExternalRotation?.equipmentType == "弹力带")
        #expect(bandExternalRotation?.primaryRegions.isEmpty == true)
    }

    @Test func researchedShoulderAdditions() {
        let byCode = Dictionary(uniqueKeysWithValues: BuiltinExercise.starter.map { ($0.code, $0) })

        let cableUprightRow = byCode["CABLE_UPRIGHT_ROW"]
        #expect(cableUprightRow?.name == "绳索直立划船")
        #expect(cableUprightRow?.category == "肩")
        #expect(cableUprightRow?.subcategory == "中束")
        #expect(cableUprightRow?.equipmentType == "绳索")
        #expect(cableUprightRow?.primaryRegions == [.deltSide])
        #expect(cableUprightRow?.secondaryRegions == [.deltFront, .traps, .biceps])
        #expect(ExerciseLibrary.resolve(code: nil, name: "绳索站姿提拉")?.code == "CABLE_UPRIGHT_ROW")

        let supinatedLateralRaise = byCode["SUPINATED_DB_LATERAL_RAISE"]
        #expect(supinatedLateralRaise?.name == "掌心向上哑铃侧平举")
        #expect(supinatedLateralRaise?.category == "肩")
        #expect(supinatedLateralRaise?.subcategory == "前束")
        #expect(supinatedLateralRaise?.equipmentType == "哑铃")
        #expect(supinatedLateralRaise?.primaryRegions == [.deltFront])
        #expect(supinatedLateralRaise?.secondaryRegions == [.deltSide, .deltRear])
        #expect(ExerciseLibrary.resolve(code: nil, name: "反握哑铃侧平举")?.code == "SUPINATED_DB_LATERAL_RAISE")
    }

    /// V1 收敛为单一预置库，不再把 1000+ 导入动作全量展示。
    @Test func libraryScale() {
        #expect(BuiltinExercise.starter.count >= 200)
        #expect(BuiltinExercise.starter.count <= 260)
    }

    @Test func removedExercisesAreNotPresetSelectable() {
        let names = Set(BuiltinExercise.starter.map(\.name))
        for gone in ["派克俯卧撑", "扎特曼弯举", "JM 推", "西西深蹲", "弹力带蚌式", "TraditionalStrengthTraining", "沙发伸展"] {
            #expect(!names.contains(gone), "明确移除动作不应在 V1 预置库: \(gone)")
            #expect(ExerciseLibrary.isRemovedFromNewSelection(gone))
        }
        #expect(ExerciseLibrary.isRemovedFromNewSelection("跑步（有氧）"))
    }

    @Test func aliasesResolveToStandardExercises() {
        #expect(ExerciseLibrary.resolve(code: "LAT_PULLDOWN", name: "宽距下拉")?.name == "高位下拉")
        #expect(ExerciseLibrary.resolve(code: "PEC_DECK_FLY", name: "器械飞鸟")?.name == "蝴蝶机夹胸")
        #expect(ExerciseLibrary.resolve(code: "CABLE_CROSSOVER", name: "绳索十字夹胸")?.name == "绳索夹胸")
        #expect(ExerciseLibrary.resolve(code: "DB_ROTATING_CURL", name: "哑铃轮换弯举")?.name == "哑铃交替弯举")
        #expect(ExerciseLibrary.resolve(code: "FACE_PULL", name: "面拉")?.name == "绳索面拉")
        #expect(ExerciseLibrary.resolve(code: "MACHINE_ROW", name: "器械单臂划船")?.name == "单臂器械划船")
        #expect(ExerciseLibrary.resolve(code: nil, name: "哑铃臂屈伸后踢")?.name == "哑铃臂屈伸")
        #expect(ExerciseLibrary.resolve(code: nil, name: "肩关节外旋训练")?.name == "弹力带肩外旋")
        #expect(ExerciseLibrary.resolve(code: nil, name: "招财猫式肩外旋")?.name == "招财猫")
        #expect(ExerciseLibrary.resolve(code: "SHOULDER_WARMUP", name: "练肩热身")?.name == "肩部动态热身")
    }

    @Test func aliasSearchReturnsOnlyStandardExercise() {
        let crossoverMatches = BuiltinExercise.starter.filter { ExerciseSearch.matches($0, query: "绳索十字夹胸") }
        #expect(crossoverMatches.map(\.name) == ["绳索夹胸"])

        let rotatingCurlMatches = BuiltinExercise.starter.filter { ExerciseSearch.matches($0, query: "哑铃轮换弯举") }
        #expect(rotatingCurlMatches.map(\.name) == ["哑铃交替弯举"])

        let externalRotationMatches = BuiltinExercise.starter.filter { ExerciseSearch.matches($0, query: "肩关节外旋训练") }
        #expect(externalRotationMatches.map(\.name) == ["弹力带肩外旋"])

        let beckoningCatMatches = BuiltinExercise.starter.filter { ExerciseSearch.matches($0, query: "招财猫式肩外旋") }
        #expect(beckoningCatMatches.map(\.name) == ["招财猫"])
    }

    @Test func independentExercisesAreNotMerged() {
        let names = Set(BuiltinExercise.starter.map(\.name))
        #expect(names.contains("直杆绳索弯举"))
        #expect(names.contains("绳索弯举"))
        #expect(names.contains("悍马机卧推"))
        #expect(names.contains("悍马机推胸"))
        #expect(names.contains("器械倒蹬机"))
        #expect(ExerciseLibrary.resolve(code: "LEG_PRESS", name: "腿举")?.name == "器械倒蹬机")
    }

    @Test func planItemDisplaysStandardNameForLegacyReference() {
        let pecDeck = PlanItem(builtinExerciseCode: "PEC_DECK_FLY",
                               exerciseName: "器械飞鸟",
                               orderIndex: 0)
        #expect(pecDeck.displayExerciseName == "蝴蝶机夹胸")

        let machineRow = PlanItem(builtinExerciseCode: "MACHINE_ROW",
                                  exerciseName: "器械单臂划船",
                                  orderIndex: 1)
        #expect(machineRow.displayExerciseName == "单臂器械划船")
    }

    @Test func historyKeysUseCanonicalAliasCode() {
        let legacyWorkoutExercise = WorkoutExercise(
            builtinExerciseCode: "CABLE_FLY",
            exerciseName: "绳索夹胸",
            orderIndex: 0
        )
        let canonicalWorkoutExercise = WorkoutExercise(
            builtinExerciseCode: "CABLE_CROSSOVER",
            exerciseName: "绳索十字夹胸",
            orderIndex: 1
        )
        let legacyPlanItem = PlanItem(
            builtinExerciseCode: "CABLE_FLY",
            exerciseName: "绳索夹胸",
            orderIndex: 0
        )

        #expect(legacyWorkoutExercise.historyKey == "CABLE_CROSSOVER")
        #expect(canonicalWorkoutExercise.historyKey == "CABLE_CROSSOVER")
        #expect(legacyPlanItem.historyKey == "CABLE_CROSSOVER")
    }

    // MARK: 5.4 中文模糊多词搜索

    @Test func searchMultiKeywordAND() {
        // 顺序无关：两种词序都命中。
        #expect(ExerciseSearch.matches("平板杠铃卧推", query: "杠铃 卧推"))
        #expect(ExerciseSearch.matches("平板杠铃卧推", query: "卧推 杠铃"))
        // 缺词不命中。
        #expect(!ExerciseSearch.matches("平板杠铃卧推", query: "杠铃 飞鸟"))
        // 空格容错（多空格 / 全角空格）。
        #expect(ExerciseSearch.matches("平板杠铃卧推", query: "  杠铃   卧推 "))
        #expect(ExerciseSearch.matches("平板杠铃卧推", query: "杠铃\u{3000}卧推"))
        // 纯中文子串旧行为不回归。
        #expect(ExerciseSearch.matches("哑铃飞鸟", query: "飞鸟"))
        #expect(!ExerciseSearch.matches("哑铃飞鸟", query: "卧推"))
        // 空 query 恒命中。
        #expect(ExerciseSearch.matches("任意动作", query: ""))
        #expect(ExerciseSearch.matches("任意动作", query: "   "))
    }
}
