import Foundation
import SwiftData
import Testing
@testable import DontLift

@MainActor
struct WorkoutSessionStartTests {
    private struct InjectedSaveError: Error {}

    @Test func failedStartLeavesNoSessionAndRetryCreatesOne() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        context.autosaveEnabled = false
        let plan = WorkoutPlan(name: "其他计划")
        context.insert(plan)
        try context.save()
        plan.note = "未保存的备注"
        var callbacks = 0

        #expect(throws: InjectedSaveError.self) {
            _ = try WorkoutSession.start({ sampleWorkout() }, in: context,
                                          persist: { _ in throw InjectedSaveError() })
            callbacks += 1
        }
        #expect(callbacks == 0)
        #expect(WorkoutSession.activeSession(in: context) == nil)
        #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutExercise>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutSet>()) == 0)
        #expect(plan.note == "未保存的备注")

        let workout = try WorkoutSession.start({ sampleWorkout() }, in: context)
        callbacks += 1
        #expect(callbacks == 1)
        #expect(WorkoutSession.activeSession(in: context)?.localId == workout.localId)
        #expect(workout.modelContext === context)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Workout>()) == 1)
        workout.exercises.first?.sets.first?.reps = 12
        try context.save()
        let stored = try #require(try ModelContext(container).fetch(FetchDescriptor<Workout>()).first)
        #expect(stored.exercises.first?.sets.first?.reps == 12)
    }

    @Test(arguments: [false, true]) func replacementFailureRestoresOldSubtreeAndRetryReplacesOnce(synced: Bool) throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        context.autosaveEnabled = false
        let old = sampleWorkout()
        if synced { old.serverId = UUID(); old.syncStatus = .synced }
        context.insert(old)
        try context.save()
        let set = try #require(old.exercises.first?.sets.first)
        let setIdentity = set.persistentModelID
        set.weightKg = 72.5
        let originalUpdatedAt = old.updatedAt
        let originalStatus = old.syncStatusRaw

        #expect(throws: InjectedSaveError.self) {
            _ = try WorkoutSession.start({ sampleWorkout() }, replacing: old, in: context,
                                          persist: { _ in throw InjectedSaveError() })
        }
        #expect(old.isActive)
        #expect(old.updatedAt == originalUpdatedAt && old.syncStatusRaw == originalStatus)
        #expect(old.exercises.first?.sets.first?.persistentModelID == setIdentity)
        #expect(old.exercises.first?.sets.first?.weightKg == 72.5)
        #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 1)
        #expect(WorkoutSession.activeSession(in: context)?.localId == old.localId)

        let new = try WorkoutSession.start({ sampleWorkout() }, replacing: old, in: context)
        let all = try ModelContext(container).fetch(FetchDescriptor<Workout>())
        #expect(all.filter(\.isActive).map(\.localId) == [new.localId])
        #expect(all.count == 2)
        #expect(old.deletedAt != nil && old.syncStatus == .pendingDelete)
        #expect(new.modelContext === context)
        try context.save()
        let stored = try ModelContext(container).fetch(FetchDescriptor<Workout>())
        #expect(stored.filter(\.isActive).map(\.localId) == [new.localId])
    }

    @Test func unexpectedActiveSessionBlocksStartBeforeBuilding() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let old = sampleWorkout()
        context.insert(old)
        try context.save()
        var builds = 0
        #expect(throws: WorkoutSession.StartError.self) {
            _ = try WorkoutSession.start({ builds += 1; return sampleWorkout() }, in: context)
        }
        #expect(builds == 0)
        #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 1)
        #expect(old.isActive)
    }

    @Test(arguments: 0..<20) func realReadonlyReplacementKeepsExistingSession(attempt: Int) throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "WorkoutStartFailure-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "readonly.store")
        let writable = try store(url: url, allowsSave: true)
        let old = sampleWorkout()
        writable.mainContext.insert(old)
        try writable.mainContext.save()
        let readonly = try store(url: url, allowsSave: false)
        let context = readonly.mainContext
        context.autosaveEnabled = false
        let loaded = try #require(WorkoutSession.activeSession(in: context))
        let identity = loaded.persistentModelID
        let set = try #require(loaded.exercises.first?.sets.first)
        set.reps = 12
        #expect(throws: (any Error).self) {
            _ = try WorkoutSession.start({ sampleWorkout() }, replacing: loaded, in: context)
        }
        #expect(loaded.isActive && loaded.persistentModelID == identity)
        #expect(loaded.exercises.first?.sets.first?.reps == 12)
        let roots = try context.fetch(FetchDescriptor<Workout>())
        #expect(roots.map(\.localId) == [loaded.localId])
        #expect(try context.fetch(FetchDescriptor<WorkoutExercise>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<WorkoutSet>()).count == 1)
        let persisted = try ModelContext(writable).fetch(FetchDescriptor<Workout>())
        #expect(persisted.map(\.localId) == [loaded.localId])
        #expect(persisted.first?.exercises.first?.sets.first?.reps == 8)
        withExtendedLifetime(writable) {}
    }

    @Test(arguments: 0..<20) func realReadonlyStartLeavesNoCandidate(attempt: Int) throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "WorkoutCreateFailure-\(attempt)-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "readonly.store")
        let writable = try store(url: url, allowsSave: true)
        let plan = WorkoutPlan(name: "其他计划")
        writable.mainContext.insert(plan)
        try writable.mainContext.save()
        let readonly = try store(url: url, allowsSave: false)
        let context = readonly.mainContext
        context.autosaveEnabled = false
        let loaded = try #require(try context.fetch(FetchDescriptor<WorkoutPlan>()).first)
        loaded.note = "保留未保存的备注"
        #expect(throws: (any Error).self) {
            _ = try WorkoutSession.start({ sampleWorkout() }, in: context)
        }
        #expect(try context.fetch(FetchDescriptor<Workout>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<WorkoutExercise>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<WorkoutSet>()).isEmpty)
        #expect(loaded.note == "保留未保存的备注")
        #expect(try ModelContext(writable).fetchCount(FetchDescriptor<Workout>()) == 0)
        withExtendedLifetime(writable) {}
    }

    private func sampleWorkout() -> Workout {
        Workout(title: "开始训练测试", exercises: [
            WorkoutExercise(builtinExerciseCode: "BB_BENCH_PRESS", exerciseName: "卧推", orderIndex: 0,
                            sets: [WorkoutSet(setIndex: 0, weightKg: 60, reps: 8)])
        ])
    }

    private func store(url: URL, allowsSave: Bool) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: AppModelContainer.schema, url: url,
                                               allowsSave: allowsSave, cloudKitDatabase: .none)
        return try ModelContainer(for: AppModelContainer.schema, configurations: [configuration])
    }
}
