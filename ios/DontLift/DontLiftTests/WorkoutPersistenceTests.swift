import Foundation
import SwiftData
import Testing
@testable import DontLift

@MainActor
struct WorkoutPersistenceTests {
    private struct InjectedSaveError: Error {}

    enum UnobservedOperation { case finish, delete, discard }

    @Test(arguments: [UnobservedOperation.finish, .delete, .discard])
    func unobservedSubtreeCanRecoverFromLifecycleFailure(operation: UnobservedOperation) throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        context.autosaveEnabled = false
        let exerciseId = UUID()
        let setId = UUID()
        let workout = Workout(exercises: [
            WorkoutExercise(localId: exerciseId, exerciseName: "未读取的动作", orderIndex: 0,
                            sets: [WorkoutSet(localId: setId, setIndex: 0, weightKg: 60, reps: 8)])
        ])
        context.insert(workout)
        try context.save()
        // 刻意不在删除前遍历子节点属性，覆盖页面尚未展开过的训练。
        #expect(throws: InjectedSaveError.self) {
            let fail: (ModelContext) throws -> Void = { _ in throw InjectedSaveError() }
            switch operation {
            case .finish:
                _ = try WorkoutPersistence.finish(workout, in: context, bodyWeightKg: nil, persist: fail)
            case .delete:
                try WorkoutPersistence.delete(workout, in: context, persist: fail)
            case .discard:
                try WorkoutPersistence.discard(workout, in: context, persist: fail)
            }
        }
        #expect(workout.isActive)
        #expect(workout.exercises.first?.localId == exerciseId)
        #expect(workout.exercises.first?.sets.first?.localId == setId)
        #expect(workout.exercises.first?.sets.first?.weightKg == 60)
    }

    @Test func failedFinishRestoresOnlyItsMutationAndCanRetry() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        context.autosaveEnabled = false
        let (workout, plan) = fixture()
        let other = WorkoutPlan(name: "其他计划")
        context.insert(workout)
        context.insert(plan)
        context.insert(other)
        try context.save()
        other.name = "保留尚未保存的编辑"
        let before = snapshot(workout)
        let planItems = plan.items
        let planUpdatedAt = plan.updatedAt
        let planStatus = plan.syncStatusRaw
        let end = Date(timeIntervalSince1970: 1_800_003_600)

        #expect(throws: InjectedSaveError.self) {
            _ = try WorkoutPersistence.finish(workout, in: context, endedAt: end, bodyWeightKg: 70,
                                               persist: { _ in throw InjectedSaveError() })
        }

        #expect(workout.isActive)
        #expect(snapshot(workout) == before)
        #expect(plan.items == planItems)
        #expect(plan.updatedAt == planUpdatedAt && plan.syncStatusRaw == planStatus)
        #expect(other.name == "保留尚未保存的编辑")
        #expect(context.undoManager == nil)

        let receipt = try WorkoutPersistence.finish(workout, in: context, endedAt: end, bodyWeightKg: 70)
        #expect(workout.isFinished)
        #expect(workout.endedAt == end && workout.bodyWeightKgAtCompletion == 70)
        #expect(workout.exercises.count == 1)
        #expect(workout.exercises.first?.sets.count == 1)
        #expect(workout.exercises.first?.sets.first?.segments.count == 1)
        #expect(receipt?.snapshot == planItems)
        let reread = try #require(try ModelContext(container).fetch(FetchDescriptor<Workout>()).first)
        #expect(reread.isFinished)
        #expect(try ModelContext(container).fetch(FetchDescriptor<WorkoutPlan>()).contains { $0.name == "保留尚未保存的编辑" })
    }

    @Test func realReadonlyStoreRestoresLifecycleMutationsAndUnrelatedEdit() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "WorkoutSaveFailure-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "readonly.store")
        let writable = try makeStore(url: url, allowsSave: true)
        let (workout, plan) = fixture()
        let other = WorkoutPlan(name: "其他计划")
        writable.mainContext.insert(workout)
        writable.mainContext.insert(plan)
        writable.mainContext.insert(other)
        try writable.mainContext.save()
        let readonly = try makeStore(url: url, allowsSave: false)
        let context = readonly.mainContext
        context.autosaveEnabled = false
        let loaded = try #require(try context.fetch(FetchDescriptor<Workout>()).first)
        let loadedOther = try #require(try context.fetch(FetchDescriptor<WorkoutPlan>()).first { $0.localId == other.localId })
        loadedOther.name = "未保存的其他编辑"
        let before = snapshot(loaded)
        let loadedPlan = try #require(try context.fetch(FetchDescriptor<WorkoutPlan>()).first { $0.localId == plan.localId })
        let items = loadedPlan.items

        #expect(throws: (any Error).self) {
            _ = try WorkoutPersistence.finish(loaded, in: context, bodyWeightKg: 70)
        }

        #expect(snapshot(loaded) == before)
        #expect(loadedPlan.items == items)
        #expect(loadedOther.name == "未保存的其他编辑")
        #expect(loaded.isActive)
        #expect(throws: (any Error).self) { try WorkoutPersistence.delete(loaded, in: context) }
        #expect(snapshot(loaded) == before)
        #expect(loadedOther.name == "未保存的其他编辑")
        #expect(throws: (any Error).self) { try WorkoutPersistence.discard(loaded, in: context) }
        #expect(snapshot(loaded) == before)
        #expect(loadedOther.name == "未保存的其他编辑")
        withExtendedLifetime(writable) {}
    }

    @Test func failedFinishKeepsRunningRestAndRetrySettlesItOnce() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        context.autosaveEnabled = false
        let (workout, plan) = fixture()
        context.insert(workout)
        context.insert(plan)
        try context.save()
        let set = try #require(workout.exercises.flatMap(\.sets).first { $0.completed })
        set.plannedRestSeconds = 90
        set.actualRestSeconds = 60
        try context.save()
        let timer = RestTimerController()
        timer.start(duration: 30, setId: set.localId)
        defer { timer.stop() }
        let end = try #require(timer.endDate)
        let event = try #require(timer.previewCompletionForWorkoutFinish())
        #expect(timer.endDate == end && timer.completionEvent == nil)
        #expect(event.elapsedSeconds == 30 && event.targetSeconds == 30)

        #expect(throws: InjectedSaveError.self) {
            _ = try WorkoutPersistence.finish(workout, in: context, bodyWeightKg: nil,
                                               rest: event, continuedRestBase: 60,
                                               persist: { _ in throw InjectedSaveError() })
        }
        #expect(timer.endDate == end && timer.completionEvent == nil)
        #expect(set.plannedRestSeconds == 90 && set.actualRestSeconds == 60)

        _ = try WorkoutPersistence.finish(workout, in: context, bodyWeightKg: nil,
                                           rest: timer.previewCompletionForWorkoutFinish(), continuedRestBase: 60)
        #expect(set.plannedRestSeconds == 120 && set.actualRestSeconds == 90)
        timer.stop()
        #expect(timer.endDate == nil)
    }

    @Test func failedDeleteRestoresMetadataAndRetryCreatesTombstone() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        context.autosaveEnabled = false
        let (workout, _) = fixture()
        workout.endedAt = .now
        workout.serverId = UUID()
        workout.syncStatus = .synced
        context.insert(workout)
        try context.save()
        let before = snapshot(workout)
        #expect(throws: InjectedSaveError.self) {
            try WorkoutPersistence.delete(workout, in: context, persist: { _ in throw InjectedSaveError() })
        }
        #expect(snapshot(workout) == before && workout.isFinished)
        try WorkoutPersistence.delete(workout, in: context)
        let reread = try #require(try ModelContext(container).fetch(FetchDescriptor<Workout>()).first)
        #expect(reread.deletedAt != nil && reread.syncStatus == .pendingDelete)
        #expect(reread.exercises.count == 2)
    }

    @Test(arguments: [false, true]) func failedDiscardKeepsSubtreeAndRetryPreservesDeletionSemantics(synced: Bool) throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        context.autosaveEnabled = false
        let (workout, _) = fixture()
        if synced {
            workout.serverId = UUID()
            workout.syncStatusRaw = SyncStatus.synced.rawValue
        }
        context.insert(workout)
        try context.save()
        let before = snapshot(workout)
        #expect(throws: InjectedSaveError.self) {
            try WorkoutPersistence.discard(workout, in: context, persist: { _ in throw InjectedSaveError() })
        }
        #expect(snapshot(workout) == before)
        #expect(workout.isActive)
        #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 1)
        try WorkoutPersistence.discard(workout, in: context)
        let reread = try #require(try ModelContext(container).fetch(FetchDescriptor<Workout>()).first)
        #expect(reread.deletedAt != nil && reread.syncStatus == .pendingDelete && !reread.isActive)
        #expect(reread.exercises.count == 2)
        #expect(reread.exercises.flatMap(\.sets).count == 3)
    }

    private func makeStore(url: URL, allowsSave: Bool) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: AppModelContainer.schema, url: url,
                                               allowsSave: allowsSave, cloudKitDatabase: .none)
        return try ModelContainer(for: AppModelContainer.schema, configurations: [configuration])
    }

    private func fixture() -> (Workout, WorkoutPlan) {
        let item = PlanItem(exerciseName: "卧推", orderIndex: 0, suggestedSets: 1,
                            suggestedReps: 8, suggestedWeightKg: 40)
        let plan = WorkoutPlan(name: "自适应测试", items: [item], mode: .adaptive)
        let completed = WorkoutSet(setIndex: 0, completed: true, setType: .drop, segments: [
            .init(segmentIndex: 0, weightKg: 60, reps: 8), .init(segmentIndex: 1)
        ])
        let incomplete = WorkoutSet(setIndex: 1, weightKg: 60, reps: 8)
        let exercise = WorkoutExercise(exerciseName: "卧推", orderIndex: 0,
                                       planItemId: item.itemId, sets: [completed, incomplete])
        let empty = WorkoutExercise(exerciseName: "尚未完成的动作", orderIndex: 1,
                                    sets: [WorkoutSet(setIndex: 0, weightKg: 20, reps: 10)])
        let workout = Workout(planId: plan.localId, title: "保存边界测试",
                               startedAt: Date(timeIntervalSince1970: 1_800_000_000), exercises: [exercise, empty])
        workout.updateTrainingUnits([
            WorkoutUnit(kind: .dropSet, orderIndex: 0, singleExerciseId: exercise.localId),
            WorkoutUnit(kind: .singleExercise, orderIndex: 1, singleExerciseId: empty.localId)
        ])
        return (workout, plan)
    }

    private struct Snapshot: Equatable {
        let id: PersistentIdentifier
        let endedAt: Date?
        let weight: Double?
        let deletedAt: Date?
        let updatedAt: Date
        let status: String
        let units: String?
        let children: [String]
    }

    private func snapshot(_ workout: Workout) -> Snapshot {
        Snapshot(id: workout.persistentModelID, endedAt: workout.endedAt,
                 weight: workout.bodyWeightKgAtCompletion, deletedAt: workout.deletedAt,
                 updatedAt: workout.updatedAt, status: workout.syncStatusRaw, units: workout.unitsJSON,
                 children: workout.exercises.sorted { $0.orderIndex < $1.orderIndex }.flatMap { exercise in
            ["\(exercise.localId)|\(exercise.persistentModelID)"] + exercise.sets.sorted { $0.setIndex < $1.setIndex }.map {
                "\($0.localId)|\($0.persistentModelID)|\($0.weightKg ?? -1)|\($0.reps ?? -1)|\($0.segments)|\($0.plannedRestSeconds ?? -1)|\($0.actualRestSeconds ?? -1)"
            }
        })
    }
}
