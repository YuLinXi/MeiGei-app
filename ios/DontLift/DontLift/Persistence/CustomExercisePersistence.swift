import Foundation
import SwiftData

@MainActor
enum CustomExercisePersistence {
    static func create(name: String, primaryMuscle: String?, equipmentType: String?,
                       in context: ModelContext,
                       persist: (ModelContext) throws -> Void = { try LocalModelSave.save($0) }) throws -> UUID {
        let exercise = CustomExercise(name: name.trimmingCharacters(in: .whitespaces),
                                      primaryMuscle: primaryMuscle, equipmentType: equipmentType)
        // 失败插入可能残留在 SwiftData context 缓存；新对象在独立 context 可靠保存后才对列表可见。
        let creationContext = ModelContext(context.container)
        creationContext.autosaveEnabled = false
        creationContext.insert(exercise)
        #if DEBUG
        try UITestHooks.failFirstSaveIfNeeded("exercise")
        #endif
        try persist(creationContext)
        return exercise.localId
    }

    static func delete(_ exercise: CustomExercise, in context: ModelContext,
                       persist: (ModelContext) throws -> Void = { try LocalModelSave.save($0) }) throws {
        _ = exercise.localId
        try LocalModelCommit.perform(in: context, persist: { context in
            #if DEBUG
            try UITestHooks.failFirstSaveIfNeeded("exercise")
            #endif
            try persist(context)
        }) { exercise.markDeleted() }
    }
}
