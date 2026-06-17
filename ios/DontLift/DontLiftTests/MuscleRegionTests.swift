//
//  MuscleRegionTests.swift
//  DontLiftTests
//
//  MuscleRegion 高亮叶级契约：与解剖三级树对齐补区后共 20 区、rawValue 唯一且 ASCII、
//  每区有中文名；curated 153 回填仍带主动肌与 ≥3 要点。
//

import Testing
@testable import DontLift

struct MuscleRegionTests {

    /// 补 deltSide/rhomboids/gluteMed/neck 后共 20 区。
    @Test func twentyRegions() {
        #expect(MuscleRegion.allCases.count == 20)
    }

    @Test func rawValuesUnique() {
        let raws = MuscleRegion.allCases.map(\.rawValue)
        #expect(Set(raws).count == raws.count)
    }

    @Test func everyRegionHasDisplayName() {
        for r in MuscleRegion.allCases { #expect(!r.displayName.isEmpty) }
    }

    /// 资产/图层名要求：仅 ASCII 字母（camelCase）。
    @Test func rawValuesAreAssetSafe() {
        for r in MuscleRegion.allCases {
            #expect(r.rawValue.allSatisfy { $0.isLetter && $0.isASCII })
        }
    }

    /// 新增字段默认空：未回填的动作不误染高亮。
    @Test func builtinExerciseDefaultsEmptyRegions() {
        let ex = BuiltinExercise(code: "X", name: "测试", category: "胸", equipmentType: "杠铃")
        #expect(ex.primaryRegions.isEmpty)
        #expect(ex.secondaryRegions.isEmpty)
        #expect(ex.formCues.isEmpty)
    }

    /// curated 153 回填覆盖：每个 curated 动作都有主动肌与 ≥3 条要点（导入条不在此约束内）。
    @Test func curatedEnrichedWithRegionsAndCues() {
        for ex in BuiltinExercise.starter where BuiltinExercise.curatedCodes.contains(ex.code) {
            #expect(!ex.primaryRegions.isEmpty, "\(ex.code) 缺主动肌区")
            #expect(ex.formCues.count >= 3, "\(ex.code) 要点不足 3 条")
        }
    }

    @Test func benchPressEnrichedCorrectly() {
        let bench = BuiltinExercise.starter.first { $0.code == "BB_BENCH_PRESS" }
        #expect(bench?.primaryRegions == [.chest])
        #expect(bench?.secondaryRegions.contains(.triceps) == true)
        #expect(bench?.secondaryRegions.contains(.deltFront) == true)
    }
}
