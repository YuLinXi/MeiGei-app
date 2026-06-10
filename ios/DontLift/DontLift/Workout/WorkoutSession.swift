import Foundation
import SwiftData

/// 训练会话生命周期守卫（workout-session-lifecycle）。
///
/// 保证同一时刻至多一个进行中会话（`isActive`）：所有「开始训练」入口经此统一处理，
/// 存在进行中会话时不静默新建，而是交由上层弹「继续 / 丢弃」。
enum WorkoutSession {

    /// 查询当前唯一进行中会话（`deletedAt == nil && endedAt == nil`），按开始时间倒序取最近一个。
    static func activeSession(in context: ModelContext) -> Workout? {
        var descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.deletedAt == nil && $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// 丢弃进行中会话：从未同步过（`serverId == nil`）直接硬删（不留无意义墓碑），
    /// 否则软删墓碑由 `SyncEngine` push 至后端。
    static func discard(_ workout: Workout, in context: ModelContext) {
        if workout.serverId == nil {
            context.delete(workout)
        } else {
            workout.markDeleted()
        }
        try? context.save()
    }
}
