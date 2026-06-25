//
//  AdaptivePlanTests.swift
//  DontLiftTests
//
//  训练计划严格/自适应模式（change workout-plan-adaptive-mode）：
//  开始训练落值（PlanPrefill）、自适应回写合并（PlanWriteback）、统计口径收紧（countsForStats）。
//

import Foundation
import Testing
import SwiftData
@testable import DontLift

@MainActor
struct AdaptivePlanTests {

    // MARK: 测试数据工具

    /// 造一个已完成训练：单动作 + 若干 (重量, 次数, 完成, 类型) 组。
    private func makeWorkout(historyKey code: String, name: String = "卧推",
                             startedAt: Date,
                             sets: [(w: Double?, r: Int?, done: Bool, type: WorkoutSetType)],
                             planId: UUID? = nil, planItemId: UUID? = nil) -> Workout {
        let w = Workout(planId: planId, startedAt: startedAt, endedAt: startedAt.addingTimeInterval(3600))
        let ex = WorkoutExercise(builtinExerciseCode: code, exerciseName: name, orderIndex: 0,
                                 planItemId: planItemId)
        ex.sets = sets.enumerated().map { idx, s in
            WorkoutSet(setIndex: idx, weightKg: s.w, reps: s.r, completed: s.done, setType: s.type)
        }
        w.exercises = [ex]
        return w
    }

    // MARK: - countsForStats 收紧

    @Test func countsForStatsRequiresCompletedAndNonWarmup() {
        let done = WorkoutSet(setIndex: 0, weightKg: 60, reps: 8, completed: true, setType: .working)
        let notDone = WorkoutSet(setIndex: 1, weightKg: 60, reps: 8, completed: false, setType: .working)
        let warmupDone = WorkoutSet(setIndex: 2, weightKg: 20, reps: 12, completed: true, setType: .warmup)
        #expect(done.countsForStats)
        #expect(!notDone.countsForStats)        // 未打勾的预填组不计入
        #expect(!warmupDone.countsForStats)     // 热身组不计入
    }

    // MARK: - PlanPrefill 开始训练落值

    @Test func strictModePrefillsPlanValues() {
        let item = PlanItem(builtinExerciseCode: "BB_BENCH", exerciseName: "卧推", orderIndex: 0,
                            suggestedSets: 4, suggestedReps: 8, suggestedWeightKg: 60)
        let sets = PlanPrefill.sets(for: item, mode: .strict, history: [])
        #expect(sets.count == 4)
        #expect(sets.allSatisfy { $0.weightKg == 60 && $0.reps == 8 && !$0.completed })
    }

    @Test func strictModeDoesNotCreateFallbackSetsWhenRequiredPresetMissing() {
        let missingSets = PlanItem(builtinExerciseCode: "BB_BENCH", exerciseName: "卧推", orderIndex: 0,
                                   suggestedSets: nil, suggestedReps: 8, suggestedWeightKg: 60)
        let missingReps = PlanItem(builtinExerciseCode: "SQUAT", exerciseName: "深蹲", orderIndex: 1,
                                   suggestedSets: 3, suggestedReps: nil, suggestedWeightKg: 100)

        #expect(PlanPrefill.missingStrictRequiredItems(in: [missingSets, missingReps]).count == 2)
        #expect(PlanPrefill.sets(for: missingSets, mode: .strict, history: []).isEmpty)
        #expect(PlanPrefill.sets(for: missingReps, mode: .strict, history: []).isEmpty)
    }

    @Test func adaptivePrefillsFromHistoryFirst() {
        let key = "BB_BENCH"
        let history = [makeWorkout(historyKey: key, startedAt: Date(timeIntervalSince1970: 1000),
                                   sets: [(62.5, 8, true, .working), (62.5, 8, true, .working), (62.5, 7, true, .working)])]
        let item = PlanItem(builtinExerciseCode: key, exerciseName: "卧推", orderIndex: 0,
                            suggestedSets: 3, suggestedReps: 8, suggestedWeightKg: 60)
        let sets = PlanPrefill.sets(for: item, mode: .adaptive, history: history)
        #expect(sets.count == 3)
        #expect(sets[0].weightKg == 62.5 && sets[0].reps == 8)   // 历史优先，非计划 60
        #expect(sets[2].reps == 7)                                // 逐组对位
    }

    @Test func adaptivePrefillMergesAliasHistoryKeys() {
        let history = [makeWorkout(historyKey: "CABLE_FLY", name: "绳索夹胸",
                                   startedAt: Date(timeIntervalSince1970: 1000),
                                   sets: [(22.5, 12, true, .working)])]
        let item = PlanItem(builtinExerciseCode: "CABLE_CROSSOVER",
                            exerciseName: "绳索十字夹胸",
                            orderIndex: 0,
                            suggestedSets: 1,
                            suggestedReps: 10,
                            suggestedWeightKg: 15)

        let sets = PlanPrefill.sets(for: item, mode: .adaptive, history: history)

        #expect(sets.count == 1)
        #expect(sets[0].weightKg == 22.5)
        #expect(sets[0].reps == 12)
    }

    @Test func adaptiveFallsBackToPlanWhenNoHistory() {
        let item = PlanItem(builtinExerciseCode: "NEW", exerciseName: "新动作", orderIndex: 0,
                            suggestedSets: 2, suggestedReps: 10, suggestedWeightKg: 40)
        let sets = PlanPrefill.sets(for: item, mode: .adaptive, history: [])
        #expect(sets.count == 2)
        #expect(sets.allSatisfy { $0.weightKg == 40 && $0.reps == 10 })
    }

    @Test func adaptiveDefaultsToFourSetsWhenPlanAndHistoryAreEmpty() {
        let item = PlanItem(builtinExerciseCode: "NEW", exerciseName: "新动作", orderIndex: 0,
                            suggestedSets: nil, suggestedReps: PlanDefaults.suggestedReps, suggestedWeightKg: nil)
        let sets = PlanPrefill.sets(for: item, mode: .adaptive, history: [])
        #expect(PlanDefaults.suggestedSets == 4)
        #expect(PlanDefaults.suggestedReps == 10)
        #expect(sets.count == 4)
        #expect(sets.allSatisfy { $0.reps == 10 && !$0.completed })
    }

    @Test func adaptiveIgnoresIncompleteHistorySets() {
        let key = "BB_BENCH"
        // 上次只有第 1 组打勾，第 2 组未完成（不应作为历史回填源）。
        let history = [makeWorkout(historyKey: key, startedAt: Date(timeIntervalSince1970: 1000),
                                   sets: [(70, 5, true, .working), (70, 5, false, .working)])]
        let item = PlanItem(builtinExerciseCode: key, exerciseName: "卧推", orderIndex: 0,
                            suggestedSets: 2, suggestedReps: 8, suggestedWeightKg: 50)
        let sets = PlanPrefill.sets(for: item, mode: .adaptive, history: history)
        #expect(sets[0].weightKg == 70)   // 第 1 组来自历史 completed
        #expect(sets[1].weightKg == 50)   // 第 2 组无历史 completed → 回退计划值
    }

    @Test func adaptivePrefillUsesPlanItemIdBeforeHistoryKeyForDuplicateExercises() {
        let key = "BB_BENCH"
        let firstId = UUID()
        let secondId = UUID()
        let first = WorkoutExercise(builtinExerciseCode: key, exerciseName: "卧推", orderIndex: 0,
                                    planItemId: firstId)
        first.sets = [WorkoutSet(setIndex: 0, weightKg: 80, reps: 3, completed: true)]
        let second = WorkoutExercise(builtinExerciseCode: key, exerciseName: "卧推", orderIndex: 1,
                                     planItemId: secondId)
        second.sets = [WorkoutSet(setIndex: 0, weightKg: 55, reps: 12, completed: true)]
        let history = [Workout(startedAt: Date(timeIntervalSince1970: 1000),
                               endedAt: Date(timeIntervalSince1970: 4600),
                               exercises: [first, second])]
        let secondItem = PlanItem(itemId: secondId, builtinExerciseCode: key, exerciseName: "卧推",
                                  orderIndex: 1, suggestedSets: 1, suggestedReps: 8, suggestedWeightKg: 60)

        let sets = PlanPrefill.sets(for: secondItem, mode: .adaptive, history: history)

        #expect(sets.count == 1)
        #expect(sets[0].weightKg == 55)
        #expect(sets[0].reps == 12)
    }

    // MARK: - PlanPrescriptionPreview 下次有效处方

    @Test func prescriptionPreviewUsesHistoryAndMatchesPrefillSets() {
        let key = "BB_BENCH"
        let date = Date(timeIntervalSince1970: 1000)
        let history = [makeWorkout(historyKey: key, startedAt: date,
                                   sets: [(62.5, 8, true, .working), (65, 5, true, .working)])]
        let item = PlanItem(builtinExerciseCode: key, exerciseName: "卧推", orderIndex: 0,
                            suggestedSets: 2, suggestedReps: 8, suggestedWeightKg: 60)

        let preview = PlanPrescriptionPreview.make(for: item, mode: .adaptive, history: history)
        let prefill = PlanPrefill.sets(for: item, mode: .adaptive, history: history)

        #expect(preview.sets.count == prefill.count)
        #expect(preview.sets[0].weightKg == prefill[0].weightKg)
        #expect(preview.sets[1].reps == prefill[1].reps)
        #expect(preview.summaryText == "下次 2 组 · 65 kg × 5")
        if case .history(let sourceDate) = preview.source {
            #expect(sourceDate == date)
        } else {
            #expect(Bool(false))
        }
    }

    @Test func prescriptionPreviewUsesPlanPresetWhenNoHistory() {
        let item = PlanItem(builtinExerciseCode: "ROW", exerciseName: "划船", orderIndex: 0,
                            suggestedSets: 4, suggestedReps: 10, suggestedWeightKg: nil)

        let preview = PlanPrescriptionPreview.make(for: item, mode: .adaptive, history: [])

        #expect(preview.source == .planPreset)
        #expect(preview.summaryText == "下次 4 组 × 10")
        #expect(preview.sets.count == PlanPrefill.sets(for: item, mode: .adaptive, history: []).count)
    }

    @Test func prescriptionPreviewUsesDefaultWhenPlanSetsAndHistoryAreMissing() {
        let item = PlanItem(builtinExerciseCode: "FLY", exerciseName: "飞鸟", orderIndex: 0,
                            suggestedSets: nil, suggestedReps: PlanDefaults.suggestedReps)

        let preview = PlanPrescriptionPreview.make(for: item, mode: .adaptive, history: [])

        #expect(preview.source == .defaultValue)
        #expect(preview.summaryText == "下次 4 组 × 10")
        #expect(preview.sets.count == PlanDefaults.suggestedSets)
    }

    @Test func prescriptionPreviewUsesStrictSourceForStrictPlans() {
        let item = PlanItem(builtinExerciseCode: "PRESS", exerciseName: "肩推", orderIndex: 0,
                            suggestedSets: 3, suggestedReps: 8, suggestedWeightKg: 40)

        let preview = PlanPrescriptionPreview.make(for: item, mode: .strict, history: [])

        #expect(preview.source == .strict)
        #expect(preview.summaryText == "下次 3 组 · 40 kg × 8")
        #expect(preview.sets.count == 3)
    }

    // MARK: - PlanWriteback 回写合并

    /// 重量/次数如实写回顶组；组数只增不减。
    @Test func mergeWritesTopSetAndMaxSets() {
        let key = "BB_BENCH"
        let itemId = UUID()
        let plan = [PlanItem(itemId: itemId, builtinExerciseCode: key, exerciseName: "卧推", orderIndex: 0,
                             suggestedSets: 5, suggestedReps: 8, suggestedWeightKg: 60)]
        // 本次完成 3 组：60×8, 60×8, 65×5（顶组 65×5）。计划现 5 组。
        let w = makeWorkout(historyKey: key, startedAt: Date(timeIntervalSince1970: 2000),
                            sets: [(60, 8, true, .working), (60, 8, true, .working), (65, 5, true, .working)],
                            planItemId: itemId)
        let result = PlanWriteback.merge(planItems: plan, workout: w)
        let updated = result.newItems.first { $0.itemId == itemId }!
        #expect(updated.suggestedWeightKg == 65)   // 顶组重量，如实
        #expect(updated.suggestedReps == 5)        // 顶组次数，如实
        #expect(updated.suggestedSets == 5)        // max(5, 3) 只增不减，不缩到 3
        #expect(result.changed)
    }

    /// 本次实绩与计划建议完全一致时，不应标脏回写或弹更新回执。
    @Test func mergeDoesNotMarkChangedWhenValuesAreUnchanged() {
        let key = "BB_BENCH"
        let itemId = UUID()
        let plan = [PlanItem(itemId: itemId, builtinExerciseCode: key, exerciseName: "卧推", orderIndex: 0,
                             suggestedSets: 3, suggestedReps: 8, suggestedWeightKg: 60)]
        let w = makeWorkout(historyKey: key, startedAt: Date(timeIntervalSince1970: 2000),
                            sets: [(60, 8, true, .working), (60, 8, true, .working), (60, 8, true, .working)],
                            planItemId: itemId)

        let result = PlanWriteback.merge(planItems: plan, workout: w)

        #expect(!result.changed)
        #expect(!result.diffs.contains { $0.kind == .updated })
        #expect(result.newItems.first?.suggestedSets == 3)
        #expect(result.newItems.first?.suggestedReps == 8)
        #expect(result.newItems.first?.suggestedWeightKg == 60)
    }

    /// deload：重量可降（如实），但组数不降。
    @Test func mergeWeightCanDecreaseSetsCannot() {
        let key = "BB_BENCH"
        let itemId = UUID()
        let plan = [PlanItem(itemId: itemId, builtinExerciseCode: key, exerciseName: "卧推", orderIndex: 0,
                             suggestedSets: 4, suggestedReps: 8, suggestedWeightKg: 80)]
        let w = makeWorkout(historyKey: key, startedAt: Date(timeIntervalSince1970: 2000),
                            sets: [(70, 10, true, .working)], planItemId: itemId)
        let updated = PlanWriteback.merge(planItems: plan, workout: w).newItems.first { $0.itemId == itemId }!
        #expect(updated.suggestedWeightKg == 70)   // 重量如实下降
        #expect(updated.suggestedSets == 4)        // 组数不降 max(4,1)
    }

    /// 训练中新增动作 append 进计划；跳过的动作保留。
    @Test func mergeAddsNewExerciseKeepsSkipped() {
        let keptId = UUID()
        let plan = [PlanItem(itemId: keptId, builtinExerciseCode: "SQUAT", exerciseName: "深蹲", orderIndex: 0,
                             suggestedSets: 3, suggestedReps: 5, suggestedWeightKg: 100)]
        // 本次没练深蹲，却练了一个不在计划里的新动作。
        let w = makeWorkout(historyKey: "CURL", name: "弯举", startedAt: Date(timeIntervalSince1970: 2000),
                            sets: [(20, 12, true, .working)], planItemId: nil)
        let result = PlanWriteback.merge(planItems: plan, workout: w)
        #expect(result.newItems.count == 2)                                   // 深蹲保留 + 弯举新增
        #expect(result.newItems.contains { $0.exerciseName == "深蹲" })        // 跳过的保留
        #expect(result.newItems.contains { $0.exerciseName == "弯举" })        // 新增 append
        #expect(result.diffs.contains { $0.kind == .added && $0.exerciseName == "弯举" })
        #expect(result.diffs.contains { $0.kind == .kept && $0.exerciseName == "杠铃深蹲" })
    }

    /// 仅热身/未完成组的动作不回写。
    @Test func mergeSkipsExerciseWithoutCompletedWorkingSets() {
        let itemId = UUID()
        let plan = [PlanItem(itemId: itemId, builtinExerciseCode: "BB_BENCH", exerciseName: "卧推", orderIndex: 0,
                             suggestedSets: 3, suggestedReps: 8, suggestedWeightKg: 60)]
        let w = makeWorkout(historyKey: "BB_BENCH", startedAt: Date(timeIntervalSince1970: 2000),
                            sets: [(20, 12, true, .warmup), (60, 8, false, .working)], planItemId: itemId)
        let result = PlanWriteback.merge(planItems: plan, workout: w)
        let item = result.newItems.first { $0.itemId == itemId }!
        #expect(item.suggestedWeightKg == 60)   // 未变（无 completed 正式组）
        #expect(item.suggestedSets == 3)
        #expect(!result.changed)                // 无实际改动
    }

    /// 去重：训练中新增动作的 historyKey 命中已有计划项时，认作更新而非重复新增。
    @Test func mergeDedupesByHistoryKey() {
        let plan = [PlanItem(itemId: UUID(), builtinExerciseCode: "BB_BENCH", exerciseName: "卧推", orderIndex: 0,
                             suggestedSets: 3, suggestedReps: 8, suggestedWeightKg: 60)]
        // planItemId=nil（如先删再手动加回），但 historyKey 仍命中。
        let w = makeWorkout(historyKey: "BB_BENCH", startedAt: Date(timeIntervalSince1970: 2000),
                            sets: [(65, 6, true, .working)], planItemId: nil)
        let result = PlanWriteback.merge(planItems: plan, workout: w)
        #expect(result.newItems.count == 1)                 // 不新增重复项
        #expect(result.newItems[0].suggestedWeightKg == 65) // 更新已有项
    }

    @Test func mergeUsesPlanItemIdBeforeHistoryKeyForDuplicateExercises() {
        let key = "BB_BENCH"
        let firstId = UUID()
        let secondId = UUID()
        let plan = [
            PlanItem(itemId: firstId, builtinExerciseCode: key, exerciseName: "卧推", orderIndex: 0,
                     suggestedSets: 3, suggestedReps: 8, suggestedWeightKg: 60),
            PlanItem(itemId: secondId, builtinExerciseCode: key, exerciseName: "卧推", orderIndex: 1,
                     suggestedSets: 2, suggestedReps: 12, suggestedWeightKg: 40)
        ]
        let w = makeWorkout(historyKey: key, startedAt: Date(timeIntervalSince1970: 2000),
                            sets: [(55, 10, true, .working), (57.5, 8, true, .working)],
                            planItemId: secondId)

        let result = PlanWriteback.merge(planItems: plan, workout: w)
        let first = result.newItems.first { $0.itemId == firstId }!
        let second = result.newItems.first { $0.itemId == secondId }!

        #expect(first.suggestedWeightKg == 60)
        #expect(first.suggestedReps == 8)
        #expect(second.suggestedWeightKg == 57.5)
        #expect(second.suggestedReps == 8)
        #expect(second.suggestedSets == 2)
    }
}
