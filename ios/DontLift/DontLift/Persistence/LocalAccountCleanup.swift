import SwiftData

@MainActor
enum LocalAccountCleanup {
    /// 服务端已删号，允许逐步清除；中途失败由会话保留清理门控，下次重试剩余内容。
    static func perform(in context: ModelContext,
                        persist: (ModelContext) throws -> Void = { try LocalModelSave.save($0) }) throws {
        #if DEBUG
        try UITestHooks.failFirstSaveIfNeeded("cleanup")
        #endif
        // 与 AppModelContainer.schema 保持一致。
        try context.delete(model: UserProfile.self)
        try context.delete(model: CustomExercise.self)
        try context.delete(model: WorkoutPlanGroup.self)
        try context.delete(model: WorkoutPlan.self)
        try context.delete(model: Workout.self)
        try context.delete(model: WorkoutExercise.self)
        try context.delete(model: WorkoutSet.self)
        try context.delete(model: BadgeGrant.self)
        try persist(context)
    }
}
