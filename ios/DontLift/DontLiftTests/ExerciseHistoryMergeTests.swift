//
//  ExerciseHistoryMergeTests.swift
//  DontLiftTests
//
//  同名动作历史合并（change exercise-library-taxonomy-import，任务 5.3）：
//  手填记录名==内置动作名 → 改挂 code、历史连续；无匹配不动；幂等可重跑。
//

import Testing
import SwiftData
@testable import DontLift

@MainActor
struct ExerciseHistoryMergeTests {

    private func makeContext() -> ModelContext {
        AppModelContainer.make(inMemory: true).mainContext
    }

    /// 旧手填记录（名==某内置动作名）迁移后 historyKey 指向该内置 code。
    @Test func mergesManualEntryByName() throws {
        let ctx = makeContext()
        // "杠铃卧推" 为精选内置动作，code = BB_BENCH_PRESS
        let ex = WorkoutExercise(builtinExerciseCode: nil, customExerciseId: nil,
                                 exerciseName: "杠铃卧推", orderIndex: 0)
        ctx.insert(ex)
        try ctx.save()

        let migrated = ExerciseHistoryMerge.run(in: ctx)
        #expect(migrated == 1)
        #expect(ex.builtinExerciseCode == "BB_BENCH_PRESS")
        #expect(ex.historyKey == "BB_BENCH_PRESS")      // 由 name 切到 code
    }

    /// 无同名内置动作的手填记录保持不变。
    @Test func leavesUnmatchedManualEntryUntouched() throws {
        let ctx = makeContext()
        let ex = WorkoutExercise(builtinExerciseCode: nil, customExerciseId: nil,
                                 exerciseName: "我的自创怪招ZZZ", orderIndex: 0)
        ctx.insert(ex)
        try ctx.save()

        _ = ExerciseHistoryMerge.run(in: ctx)
        #expect(ex.builtinExerciseCode == nil)
        #expect(ex.historyKey == "我的自创怪招ZZZ")
    }

    /// 幂等：重复执行不再迁移、数据不变。
    @Test func idempotentOnRerun() throws {
        let ctx = makeContext()
        let ex = WorkoutExercise(builtinExerciseCode: nil, customExerciseId: nil,
                                 exerciseName: "杠铃卧推", orderIndex: 0)
        ctx.insert(ex)
        try ctx.save()

        let first = ExerciseHistoryMerge.run(in: ctx)
        let second = ExerciseHistoryMerge.run(in: ctx)
        #expect(first == 1)
        #expect(second == 0)
        #expect(ex.builtinExerciseCode == "BB_BENCH_PRESS")
    }
}
