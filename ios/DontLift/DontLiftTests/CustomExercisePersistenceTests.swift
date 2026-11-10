import Foundation
import SwiftData
import Testing
@testable import DontLift

@MainActor
struct CustomExercisePersistenceTests {
    private struct SaveFailure: Error {}

    @Test func createFailureLeavesNoCandidateAndRetryCreatesOne() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        context.autosaveEnabled = false
        let other = WorkoutPlan(name: "其他计划")
        context.insert(other)
        try context.save()
        other.note = "其他未保存编辑"
        #expect(throws: SaveFailure.self) {
            try CustomExercisePersistence.create(name: " 自定义推举 ", primaryMuscle: "肩部", equipmentType: "哑铃",
                                                 in: context, persist: { _ in throw SaveFailure() })
        }
        #expect(try context.fetchCount(FetchDescriptor<CustomExercise>()) == 0)
        #expect(other.note == "其他未保存编辑")
        let exerciseId = try CustomExercisePersistence.create(name: " 自定义推举 ", primaryMuscle: "肩部",
                                                            equipmentType: "哑铃", in: context)
        let saved = try ModelContext(container).fetch(FetchDescriptor<CustomExercise>())
        #expect(saved.count == 1 && saved.first?.localId == exerciseId)
        #expect(saved.first?.name == "自定义推举" && saved.first?.primaryMuscle == "肩部")
        #expect(saved.first?.syncStatus == .pendingCreate)
    }

    @Test func deleteFailureRestoresMetadataAndKeepsHistoryReference() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        context.autosaveEnabled = false
        let exercise = CustomExercise(name: "自定义推举")
        exercise.serverId = UUID()
        exercise.syncStatus = .synced
        let row = WorkoutExercise(exerciseName: exercise.name, orderIndex: 0)
        row.customExerciseId = exercise.localId
        let workout = Workout(title: "已有记录")
        workout.exercises = [row]
        context.insert(exercise)
        context.insert(workout)
        try context.save()
        let before = (exercise.updatedAt, exercise.syncStatusRaw, exercise.version)
        #expect(throws: SaveFailure.self) {
            try CustomExercisePersistence.delete(exercise, in: context, persist: { _ in throw SaveFailure() })
        }
        #expect(exercise.deletedAt == nil && exercise.updatedAt == before.0)
        #expect(exercise.syncStatusRaw == before.1 && exercise.version == before.2)
        #expect(row.customExerciseId == exercise.localId && row.exerciseName == "自定义推举")
        try CustomExercisePersistence.delete(exercise, in: context)
        let saved = try #require(try ModelContext(container).fetch(FetchDescriptor<CustomExercise>()).first)
        #expect(saved.deletedAt != nil && saved.syncStatus == .pendingDelete)
        #expect(row.customExerciseId == exercise.localId)
    }

    @Test func readonlyStorageRejectsCreationAndRestoresFailedDelete() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "ExerciseCommit-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "readonly.store")
        let writable = try store(url: url, allowsSave: true)
        writable.mainContext.insert(CustomExercise(name: "保留动作"))
        try writable.mainContext.save()
        let readonly = try store(url: url, allowsSave: false)
        let context = readonly.mainContext
        context.autosaveEnabled = false
        let original = try #require(try context.fetch(FetchDescriptor<CustomExercise>()).first)
        #expect(throws: (any Error).self) {
            try CustomExercisePersistence.create(name: "失败创建", primaryMuscle: nil, equipmentType: nil, in: context)
        }
        // 失败候选不进入列表 context，也不进入存储。
        let remaining = try context.fetch(FetchDescriptor<CustomExercise>())
        #expect(remaining.map(\.localId) == [original.localId])
        #expect(try ModelContext(readonly).fetchCount(FetchDescriptor<CustomExercise>()) == 1)
        #expect(throws: (any Error).self) { try CustomExercisePersistence.delete(original, in: context) }
        #expect(original.deletedAt == nil && original.name == "保留动作")
        withExtendedLifetime(writable) {}
    }

    private func store(url: URL, allowsSave: Bool) throws -> ModelContainer {
        let config = ModelConfiguration(schema: AppModelContainer.schema, url: url,
                                        allowsSave: allowsSave, cloudKitDatabase: .none)
        return try ModelContainer(for: AppModelContainer.schema, configurations: [config])
    }
}
