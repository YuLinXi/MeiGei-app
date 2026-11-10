//
//  ExerciseHistoryMergeTests.swift
//  DontLiftTests
//
//  同名动作历史合并（change exercise-library-taxonomy-import，任务 5.3）：
//  手填记录名==内置动作名 → 改挂 code、历史连续；无匹配不动；幂等可重跑。
//

import Testing
import Foundation
import SwiftData
@testable import DontLift

@MainActor
struct ExerciseHistoryMergeTests {
    private struct MigrationFailure: Error {}

    @Test func failedReadOrSaveLeavesMigrationRetryableAndKeepsOtherEdits() throws {
        let container = makeContainer()
        let context = container.mainContext
        context.autosaveEnabled = false
        let ex = WorkoutExercise(exerciseName: "杠铃卧推", orderIndex: 0)
        let workout = try insertWorkout(with: ex, in: context)
        let originalUpdatedAt = workout.updatedAt
        let other = WorkoutPlan(name: "其他计划")
        context.insert(other)
        try context.save()
        other.note = "不应丢失的编辑"
        let suite = "HistoryMergeRetry.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(ExerciseHistoryMerge.runIfNeeded(in: context, defaults: defaults,
                                                 fetch: { _ in throw MigrationFailure() }) == 0)
        #expect(!defaults.bool(forKey: ExerciseHistoryMerge.completionKey))
        #expect(ExerciseHistoryMerge.runIfNeeded(in: context, defaults: defaults,
                                                 persist: { _ in throw MigrationFailure() }) == 0)
        #expect(!defaults.bool(forKey: ExerciseHistoryMerge.completionKey))
        #expect(ex.builtinExerciseCode == nil && other.note == "不应丢失的编辑")
        #expect(workout.updatedAt == originalUpdatedAt)
        #expect(ExerciseHistoryMerge.runIfNeeded(in: context, defaults: defaults) == 1)
        #expect(defaults.bool(forKey: ExerciseHistoryMerge.completionKey))
        let reread = try #require(try ModelContext(container).fetch(FetchDescriptor<WorkoutExercise>()).first)
        #expect(reread.builtinExerciseCode == "BB_BENCH_PRESS")
    }

    @Test func completedMigrationDoesNotFetchAgain() throws {
        let container = makeContainer()
        let suite = "HistoryMergeFastPath.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: ExerciseHistoryMerge.completionKey)
        var fetched = false
        #expect(ExerciseHistoryMerge.runIfNeeded(in: container.mainContext, defaults: defaults, fetch: { _ in
            fetched = true
            throw MigrationFailure()
        }) == 0)
        #expect(!fetched)
    }

    @Test func readonlySaveDoesNotMarkMigrationCompleteOrLeaveUnstoredReference() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "HistoryMerge-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "readonly.store")
        let writable = try ModelContainer(for: AppModelContainer.schema, configurations: [
            ModelConfiguration(schema: AppModelContainer.schema, url: url, cloudKitDatabase: .none)
        ])
        let ex = WorkoutExercise(exerciseName: "杠铃卧推", orderIndex: 0)
        try insertWorkout(with: ex, in: writable.mainContext)
        let readonly = try ModelContainer(for: AppModelContainer.schema, configurations: [
            ModelConfiguration(schema: AppModelContainer.schema, url: url, allowsSave: false, cloudKitDatabase: .none)
        ])
        readonly.mainContext.autosaveEnabled = false
        let loaded = try #require(try readonly.mainContext.fetch(FetchDescriptor<WorkoutExercise>()).first)
        let suite = "HistoryMergeReadonly.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let migrated = ExerciseHistoryMerge.runIfNeeded(in: readonly.mainContext, defaults: defaults)

        #expect(migrated == 0)
        #expect(!defaults.bool(forKey: ExerciseHistoryMerge.completionKey))
        #expect(loaded.builtinExerciseCode == nil)
        withExtendedLifetime(writable) {}
    }

    private func makeContainer() -> ModelContainer {
        AppModelContainer.make(inMemory: true)
    }

    @discardableResult
    private func insertWorkout(with ex: WorkoutExercise, in ctx: ModelContext) throws -> Workout {
        let workout = Workout(exercises: [ex])
        ctx.insert(workout)
        try ctx.save()
        return workout
    }

    /// 旧手填记录（名==某内置动作名）迁移后 historyKey 指向该内置 code。
    @Test func mergesManualEntryByName() throws {
        let container = makeContainer()
        let ctx = container.mainContext
        // "杠铃卧推" 为精选内置动作，code = BB_BENCH_PRESS
        let ex = WorkoutExercise(builtinExerciseCode: nil, customExerciseId: nil,
                                 exerciseName: "杠铃卧推", orderIndex: 0)
        try insertWorkout(with: ex, in: ctx)

        let migrated = ExerciseHistoryMerge.run(in: ctx)
        #expect(migrated == 1)
        #expect(ex.builtinExerciseCode == "BB_BENCH_PRESS")
        #expect(ex.historyKey == "BB_BENCH_PRESS")      // 由 name 切到 code
    }

    /// 无同名内置动作的手填记录保持不变。
    @Test func leavesUnmatchedManualEntryUntouched() throws {
        let container = makeContainer()
        let ctx = container.mainContext
        let ex = WorkoutExercise(builtinExerciseCode: nil, customExerciseId: nil,
                                 exerciseName: "我的自创怪招ZZZ", orderIndex: 0)
        try insertWorkout(with: ex, in: ctx)

        _ = ExerciseHistoryMerge.run(in: ctx)
        #expect(ex.builtinExerciseCode == nil)
        #expect(ex.historyKey == "我的自创怪招ZZZ")
    }

    /// 幂等：重复执行不再迁移、数据不变。
    @Test func idempotentOnRerun() throws {
        let container = makeContainer()
        let ctx = container.mainContext
        let ex = WorkoutExercise(builtinExerciseCode: nil, customExerciseId: nil,
                                 exerciseName: "杠铃卧推", orderIndex: 0)
        try insertWorkout(with: ex, in: ctx)

        let first = ExerciseHistoryMerge.run(in: ctx)
        let second = ExerciseHistoryMerge.run(in: ctx)
        #expect(first == 1)
        #expect(second == 0)
        #expect(ex.builtinExerciseCode == "BB_BENCH_PRESS")
    }

    /// 启动入口只执行一次；完成标记存在时不再全量 fetch `WorkoutExercise`。
    @Test func runIfNeededSkipsAfterCompletionFlag() throws {
        let suiteName = "ExerciseHistoryMergeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let container = makeContainer()
        let ctx = container.mainContext
        let ex = WorkoutExercise(builtinExerciseCode: nil, customExerciseId: nil,
                                 exerciseName: "杠铃卧推", orderIndex: 0)
        try insertWorkout(with: ex, in: ctx)

        let first = ExerciseHistoryMerge.runIfNeeded(in: ctx, defaults: defaults)
        ex.builtinExerciseCode = nil
        let second = ExerciseHistoryMerge.runIfNeeded(in: ctx, defaults: defaults)

        #expect(first == 1)
        #expect(second == 0)
        #expect(defaults.bool(forKey: ExerciseHistoryMerge.completionKey))
        #expect(ex.builtinExerciseCode == nil)
    }
}
