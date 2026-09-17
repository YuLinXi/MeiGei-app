import Foundation
import SwiftData
import Testing
@testable import DontLift

@Suite(.serialized)
@MainActor
struct BadgeWallStoreTests {
    private func workout(weight: Double = 60) -> Workout {
        Workout(startedAt: Date(timeIntervalSince1970: 1000), endedAt: Date(timeIntervalSince1970: 2000), exercises: [
            WorkoutExercise(builtinExerciseCode: "BB_BENCH_PRESS", exerciseName: "杠铃卧推", orderIndex: 0,
                            sets: [WorkoutSet(setIndex: 0, weightKg: weight, reps: 10, completed: true)])
        ])
    }

    @Test func repeatedEntryDoesNotReadOrCalculateAgain() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(workout())
        try context.save()
        let store = BadgeWallStore()
        store.configure(context: context, userId: UUID())
        #expect(store.progress.count == 24)
        await store.waitUntilLoaded()
        let first = store.progress
        #expect(store.isReady)
        #expect(store.completedRefreshCount == 1)
        for _ in 0..<10 { await store.waitUntilLoaded() }
        #expect(store.completedRefreshCount == 1)
        #expect(store.progress == first)
        #expect(store.historyReadCount == 1)
        for items in store.sections.values {
            let flags = items.map(\.isUnlocked)
            #expect(flags == flags.sorted { $0 && !$1 })
        }
    }

    @Test func saveNotificationRefreshesSameCountEditsAndDeletion() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let item = workout()
        context.insert(item)
        try context.save()
        let store = BadgeWallStore()
        store.configure(context: context, userId: UUID())
        await store.waitUntilLoaded()
        let observer = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: context, queue: .main) { notification in
            MainActor.assumeIsolated { store.saved(notification) }
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        item.exercises[0].sets[0].weightKg = 120
        item.markDirty()
        try context.save()
        await store.waitUntilLoaded()
        #expect(store.progress.first { $0.id == "tonnage_10t" }?.currentMetric == 1200)
        #expect(store.completedRefreshCount >= 2)
        item.markDeleted()
        try context.save()
        await store.waitUntilLoaded()
        #expect(store.progress.first { $0.id == "tonnage_10t" }?.currentMetric == 0)
        #expect(store.progress.first { $0.id == "career_first_workout" }?.isUnlocked == true)
    }

    @Test func activeSavesNeverReadCompletedHistory() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let item = workout()
        item.endedAt = nil
        context.insert(item)
        try context.save()
        let store = BadgeWallStore()
        store.configure(context: context, userId: UUID())
        await store.waitUntilLoaded()
        let reads = store.historyReadCount
        let observer = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: context, queue: .main) { notification in
            MainActor.assumeIsolated { store.saved(notification) }
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        for index in 0..<30 {
            let set = item.exercises[0].sets[0]
            set.completed.toggle()
            set.weightKg = Double(index)
            set.actualRestSeconds = index
            item.markDirty()
            try context.save()
            await store.waitUntilLoaded()
        }
        #expect(store.historyReadCount == reads)
        item.endedAt = .now
        try context.save()
        await store.waitUntilLoaded()
        #expect(store.historyReadCount == reads + 1)
    }

    @Test func backgroundReaderMatchesExistingRulesIncludingDropSets() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let item = workout()
        item.exercises[0].sets.append(WorkoutSet(setIndex: 1, weightKg: 100, reps: 5, completed: true, isWarmup: true))
        item.exercises[0].sets.append(WorkoutSet(setIndex: 2, completed: true, setType: .drop, segments: [
            WorkoutSetSegment(segmentIndex: 0, weightKg: 50, reps: 8),
            WorkoutSetSegment(segmentIndex: 1, weightKg: 40, reps: 10)
        ]))
        context.insert(item)
        try context.save()
        let expected = BadgeEngine.calculateProgress(allFinishedWorkouts: [item], grants: [], currentWeight: 70)
        let snapshots = try await Task.detached {
            try await BadgeHistoryReader(modelContainer: container).readWorkouts()
        }.value
        let actual = BadgeEngine.calculateProgress(workouts: snapshots, grants: [], currentWeight: 70)
        #expect(actual == expected)
        #expect(actual.first { $0.id == "tonnage_10t" }?.currentMetric == 1400)
        // 空递减组不能回退计入旧父组摘要的重量和次数。
        let emptyDrop = WorkoutSet(setIndex: 3, completed: true, setType: .drop)
        emptyDrop.weightKg = 500
        emptyDrop.reps = 10
        item.exercises[0].sets.append(emptyDrop)
        let emptyResult = BadgeEngine.calculateProgress(allFinishedWorkouts: [item], grants: [], currentWeight: 70)
        #expect(emptyResult.first { $0.id == "tonnage_10t" }?.currentMetric == item.completedStatVolumeKg)
    }

    @Test func logoutDiscardsInFlightResult() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let store = BadgeWallStore()
        store.configure(context: container.mainContext, userId: UUID())
        store.configure(context: container.mainContext, userId: nil)
        await store.waitUntilLoaded()
        #expect(store.progress.isEmpty)
        #expect(!store.isReady)
        store.configure(context: container.mainContext, userId: UUID())
        await store.waitUntilLoaded()
        #expect(store.isReady)
        #expect(store.progress.count == 24)
    }

    @Test func bodyWeightRefreshReusesHistoryAndPreservesVisibleContent() async throws {
        let previous = WorkoutCaloriePreferences.current().bodyWeightKg
        defer { WorkoutCaloriePreferences.setBodyWeightKg(previous) }
        WorkoutCaloriePreferences.setBodyWeightKg(100)
        let container = AppModelContainer.make(inMemory: true)
        container.mainContext.insert(workout())
        try container.mainContext.save()
        let store = BadgeWallStore()
        store.configure(context: container.mainContext, userId: UUID())
        await store.waitUntilLoaded()
        let old = store.progress
        let reads = store.historyReadCount
        WorkoutCaloriePreferences.setBodyWeightKg(60)
        store.invalidate(historyChanged: false)
        #expect(store.progress == old)
        #expect(store.isReady)
        await store.waitUntilLoaded()
        #expect(store.historyReadCount == reads)
        let badge = try #require(store.progress.first { $0.id == "strength_bw_bench_1_0" })
        #expect(badge.progressRatio == 1)
        #expect(!badge.isUnlocked)
    }

    @Test func overlappingChangesOnlyPublishNewestData() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let item = workout()
        container.mainContext.insert(item)
        try container.mainContext.save()
        let store = BadgeWallStore()
        store.configure(context: container.mainContext, userId: UUID())
        for weight in [80.0, 100.0, 120.0] {
            item.exercises[0].sets[0].weightKg = weight
            try container.mainContext.save()
            store.invalidate()
        }
        await store.waitUntilLoaded()
        #expect(store.progress.first { $0.id == "tonnage_10t" }?.currentMetric == 1200)
        #expect(store.completedRefreshCount == 1)
    }

    @Test func thousandWorkoutsReusePreparedResult() async throws {
        let container = AppModelContainer.make(inMemory: true)
        for _ in 0..<1000 { container.mainContext.insert(workout()) }
        try container.mainContext.save()
        let store = BadgeWallStore()
        let start = ContinuousClock.now
        store.configure(context: container.mainContext, userId: UUID())
        await store.waitUntilLoaded()
        let prepared = ContinuousClock.now
        for _ in 0..<10 { await store.waitUntilLoaded() }
        print("徽章馆 1000 场准备: \(start.duration(to: prepared))，重复进入 10 次: \(prepared.duration(to: .now))")
        #expect(store.completedRefreshCount == 1)
        #expect(store.progress.first { $0.id == "career_300_workouts" }?.currentMetric == 1000)
    }

    @Test func failedReadPreservesContentAndNextEntryRetries() async throws {
        actor Reader {
            var calls = 0
            func read() throws -> [BadgeWorkoutSnapshot] {
                calls += 1
                if calls == 2 { throw CocoaError(.fileReadUnknown) }
                return []
            }
        }
        let reader = Reader()
        let container = AppModelContainer.make(inMemory: true)
        let store = BadgeWallStore(readHistory: { _ in try await reader.read() })
        store.configure(context: container.mainContext, userId: UUID())
        await store.waitUntilLoaded()
        let content = store.progress
        store.invalidate()
        await store.waitUntilLoaded()
        #expect(store.progress == content)
        #expect(store.isReady)
        #expect(store.completedRefreshCount == 1)
        await store.waitUntilLoaded()
        #expect(store.completedRefreshCount == 2)
        #expect(await reader.calls == 3)
    }
}
