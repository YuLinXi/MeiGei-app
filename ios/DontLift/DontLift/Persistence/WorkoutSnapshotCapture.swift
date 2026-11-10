import Foundation
import SwiftData

/// 与训练写入串行复制完整聚合；跨批次只保留标识和值，不保留可被删除的模型关系。
@MainActor
enum WorkoutSnapshotCapture {
    static func read<Value: Sendable>(
        from container: ModelContainer, completedOnly: Bool, order: SortOrder,
        transform: @MainActor @Sendable (Workout) -> Value?
    ) async throws -> [Value] {
        try Task.checkCancellation()
        let predicate: Predicate<Workout>
        if completedOnly {
            predicate = #Predicate { $0.deletedAt == nil && $0.endedAt != nil }
        } else {
            predicate = #Predicate { $0.deletedAt == nil }
        }
        var descriptor = FetchDescriptor<Workout>(predicate: predicate,
                                                   sortBy: [SortDescriptor(\.startedAt, order: order)])
        descriptor.includePendingChanges = false
        let ids = try ModelContext(container).fetchIdentifiers(descriptor)
        var result: [Value] = []
        result.reserveCapacity(ids.count)
        for start in stride(from: 0, to: ids.count, by: 4) {
            try Task.checkCancellation()
            let window = Array(ids[start..<min(start + 4, ids.count)])
            result += try capture(window, from: container, completedOnly: completedOnly, transform: transform)
            await Task.yield()
        }
        try Task.checkCancellation()
        return result
    }

    /// 此同步范围结束前复制所有字段，模型和 context 不进入下一次挂起后的读取。
    private static func capture<Value: Sendable>(
        _ ids: [PersistentIdentifier], from container: ModelContainer, completedOnly: Bool,
        transform: @MainActor @Sendable (Workout) -> Value?
    ) throws -> [Value] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Workout>(predicate: #Predicate { ids.contains($0.persistentModelID) })
        descriptor.includePendingChanges = false
        let models = Dictionary(uniqueKeysWithValues: try context.fetch(descriptor).map { ($0.persistentModelID, $0) })
        return ids.compactMap { id in
            guard let workout = models[id], workout.deletedAt == nil,
                  !completedOnly || workout.endedAt != nil else { return nil }
            return transform(workout)
        }
    }
}
