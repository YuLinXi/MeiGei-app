import Foundation
import SwiftData

/// 排序只提交当前仍存活的项；关闭草稿不调用这里，失败由局部撤销恢复本次修改。
@MainActor
enum ReorderPersistence {
    static func groups(_ current: [WorkoutPlanGroup], orderedIDs: [UUID], in context: ModelContext,
                       persist: (ModelContext) throws -> Void = { try LocalModelSave.save($0) }) throws {
        let current = current.filter { $0.deletedAt == nil }
        let ordered = reordered(current, ids: orderedIDs, id: \.localId)
        guard ordered.map(\.localId) != current.map(\.localId) else { return }
        try commit(in: context, persist: persist) {
            for (index, group) in ordered.enumerated() {
                group.sortOrder = index
                group.markDirty()
            }
        }
    }

    static func plans(_ current: [WorkoutPlan], orderedIDs: [UUID], in context: ModelContext,
                      persist: (ModelContext) throws -> Void = { try LocalModelSave.save($0) }) throws {
        let current = current.filter { $0.deletedAt == nil }
        let ordered = reordered(current, ids: orderedIDs, id: \.localId)
        guard ordered.map(\.localId) != current.map(\.localId) else { return }
        try commit(in: context, persist: persist) {
            for (index, plan) in ordered.enumerated() {
                plan.sortOrder = index
                plan.markDirty()
            }
        }
    }

    static func planItems(_ plan: WorkoutPlan, orderedIDs: [UUID], in context: ModelContext,
                          persist: (ModelContext) throws -> Void = { try LocalModelSave.save($0) }) throws {
        let current = plan.items.sorted { $0.orderIndex < $1.orderIndex }
        var items = reordered(current, ids: orderedIDs, id: \.itemId)
        guard items.map(\.itemId) != current.map(\.itemId) else { return }
        for index in items.indices { items[index].orderIndex = index }
        try commit(in: context, persist: persist) {
            plan.items = items
            plan.markDirty()
        }
    }

    @discardableResult
    static func workoutUnits(_ workout: Workout, orderedIDs: [UUID], in context: ModelContext,
                             persist: (ModelContext) throws -> Void = { try LocalModelSave.save($0) }) throws -> Bool {
        let current = workout.trainingUnits
        let ordered = reordered(current, ids: orderedIDs, id: \.unitId).enumerated().map { index, unit in
            var copy = unit
            copy.orderIndex = index
            return copy
        }
        guard ordered.map(\.unitId) != current.map(\.unitId) else { return false }
        WorkoutPersistence.materializeSubtreeForCommit(workout)
        try commit(in: context, persist: persist) {
            workout.updateTrainingUnits(ordered)
            var exerciseOrder = 0
            for unit in workout.trainingUnits {
                let ids = unit.kind == .superset
                    ? unit.superset?.members.sorted { $0.orderIndex < $1.orderIndex }.map(\.exerciseId) ?? []
                    : unit.singleExerciseId.map { [$0] } ?? []
                for id in ids {
                    if let exercise = workout.exercise(id: id) {
                        exercise.orderIndex = exerciseOrder
                        exerciseOrder += 1
                    }
                }
            }
            workout.markDirty()
        }
        return true
    }

    private static func commit(in context: ModelContext,
                               persist: (ModelContext) throws -> Void,
                               mutation: () throws -> Void) throws {
        try LocalModelCommit.perform(in: context, persist: { context in
            #if DEBUG
            try UITestHooks.failFirstSaveIfNeeded("reorder")
            #endif
            try persist(context)
        }, mutation: mutation)
    }

    /// 草稿期间新增项追加在末尾，已移除项跳过；同一稳定身份最多保留一次。
    private static func reordered<Item>(_ current: [Item], ids: [UUID], id: KeyPath<Item, UUID>) -> [Item] {
        var remaining = Dictionary(uniqueKeysWithValues: current.map { ($0[keyPath: id], $0) })
        var result = ids.compactMap { remaining.removeValue(forKey: $0) }
        result.append(contentsOf: current.filter { remaining.removeValue(forKey: $0[keyPath: id]) != nil })
        return result
    }
}
