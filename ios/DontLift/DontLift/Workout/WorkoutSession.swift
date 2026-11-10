import Foundation
import SwiftData

extension Notification.Name {
    /// 进行中训练会话可能发生变化；根层据此刷新全局训练中悬浮窗。
    static let dontliftActiveWorkoutChanged = Notification.Name("dontlift.workout.active.changed")
}

/// 训练会话生命周期守卫（workout-session-lifecycle）。
///
/// 保证同一时刻至多一个进行中会话（`isActive`）：所有「开始训练」入口经此统一处理，
/// 存在进行中会话时不静默新建，而是交由上层弹「继续 / 丢弃」。
enum WorkoutSession {
    enum StartError: LocalizedError {
        case activeSessionChanged

        var errorDescription: String? { "当前训练已变化，请重新选择开始或继续。" }
    }

    /// 查询当前唯一进行中会话（`deletedAt == nil && endedAt == nil`），按开始时间倒序取最近一个。
    static func activeSession(in context: ModelContext) -> Workout? {
        try? fetchActiveSession(in: context)
    }

    private static func fetchActiveSession(in context: ModelContext) throws -> Workout? {
        var descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.deletedAt == nil && $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// 替换时把旧会话删除与新会话插入一并提交；失败恢复旧会话，不留下新会话。
    static func start(_ build: () -> Workout,
                      replacing existing: Workout? = nil,
                      in context: ModelContext,
                      persist: (ModelContext) throws -> Void = { try LocalModelSave.save($0) }) throws -> Workout {
        let current = try fetchActiveSession(in: context)
        guard current?.localId == existing?.localId else { throw StartError.activeSessionChanged }
        let workout = build()
        // 失败插入可能残留在共享context查询中，候选与旧墓碑先在独立context原子保存。
        let creationContext = ModelContext(context.container)
        creationContext.autosaveEnabled = false
        let discardedAt = Date.now
        if let existing {
            let id = existing.localId
            var descriptor = FetchDescriptor<Workout>(predicate: #Predicate { $0.localId == id })
            descriptor.fetchLimit = 1
            guard let stored = try creationContext.fetch(descriptor).first else { throw StartError.activeSessionChanged }
            stored.markDeleted(now: discardedAt)
        }
        creationContext.insert(workout)
        #if DEBUG
        try UITestHooks.failFirstSaveIfNeeded("commit")
        try UITestHooks.failFirstSaveIfNeeded("start")
        #endif
        try persist(creationContext)
        existing?.markDeleted(now: discardedAt)
        // 已可靠保存的身份在调用方context取回，后续录入继续由原保存协调器提交。
        return context.model(for: workout.persistentModelID) as! Workout
    }

    /// 丢弃已保存会话时保留墓碑；`serverId == nil` 也可能已有在途上传，不能直接硬删。
    /// 删除确认前由既有同步保护保留意图，确认后清理本机聚合。
    static func discard(_ workout: Workout, in context: ModelContext) throws {
        try WorkoutPersistence.discard(workout, in: context)
    }
}
