//
//  MuscleRegionTests.swift
//  DontLiftTests
//
//  MuscleRegion 16 区契约：数量恰为 16、rawValue 唯一、每区有非空中文名，
//  且 rawValue 仅含 ASCII 字母（高亮图资产/图层命名要逐字一致，不能含空格或中文）。
//

import Testing
@testable import DontLift

struct MuscleRegionTests {

    @Test func exactlySixteenRegions() {
        #expect(MuscleRegion.allCases.count == 16)
    }

    @Test func rawValuesUnique() {
        let raws = MuscleRegion.allCases.map(\.rawValue)
        #expect(Set(raws).count == raws.count)
    }

    @Test func everyRegionHasDisplayName() {
        for r in MuscleRegion.allCases {
            #expect(!r.displayName.isEmpty)
        }
    }

    @Test func rawValuesAreAssetSafe() {
        // 资产/图层名要求：仅 ASCII 字母（camelCase），无空格/中文/符号。
        for r in MuscleRegion.allCases {
            #expect(r.rawValue.allSatisfy { $0.isLetter && $0.isASCII })
        }
    }

    @Test func builtinExerciseDefaultsEmptyRegions() {
        // 新增字段默认空：未回填的动作不应误染高亮图。
        let ex = BuiltinExercise(code: "X", name: "测试", primaryMuscle: "胸", equipmentType: "杠铃")
        #expect(ex.primaryRegions.isEmpty)
        #expect(ex.secondaryRegions.isEmpty)
        #expect(ex.formCues.isEmpty)
    }

    @Test func everyBuiltinEnrichedWithRegionsAndCues() {
        // 153 条回填覆盖：每个内置动作都应有主动肌与 ≥3 条要点。
        for ex in BuiltinExercise.starter {
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
