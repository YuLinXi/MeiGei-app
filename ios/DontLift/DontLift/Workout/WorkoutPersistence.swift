import Foundation
import SwiftData

/// 训练生命周期操作的保存边界。失败只撤销本次操作，不回滚共享 context 中的其他编辑。
@MainActor
enum WorkoutPersistence {
    static func finish(_ workout: Workout,
                       in context: ModelContext,
                       endedAt: Date = .now,
                       bodyWeightKg: Double?,
                       rest: RestTimerController.CompletionEvent? = nil,
                       continuedRestBase: Int? = nil,
                       persist: (ModelContext) throws -> Void = { try LocalModelSave.save($0) }) throws -> PlanWritebackCenter.Receipt? {
        materializeSubtreeForCommit(workout)
        var receipt: PlanWritebackCenter.Receipt?
        try commit(workout, in: context, persist: persist) {
            if let rest,
               let set = workout.exercises.flatMap(\.sets).first(where: { $0.localId == rest.setId }),
               set.completed {
                set.plannedRestSeconds = WorkoutRestPolicy.finalPlannedRestSeconds(
                    targetSeconds: rest.targetSeconds,
                    previousPlannedSeconds: set.plannedRestSeconds,
                    isContinuation: continuedRestBase != nil)
                set.actualRestSeconds = WorkoutRestPolicy.actualRestSecondsAfterCompletion(
                    elapsedSeconds: rest.elapsedSeconds,
                    continuedBaseSeconds: continuedRestBase,
                    persistedActualRestSeconds: set.actualRestSeconds)
            }
            workout.endedAt = endedAt
            workout.bodyWeightKgAtCompletion = bodyWeightKg
            cleanupIncompleteSets(in: workout, context: context)
            workout.markDirty()

            if let planId = workout.planId {
                var descriptor = FetchDescriptor<WorkoutPlan>(
                    predicate: #Predicate { $0.localId == planId && $0.deletedAt == nil })
                descriptor.fetchLimit = 1
                if let plan = try context.fetch(descriptor).first, plan.mode == .adaptive {
                    let snapshot = plan.items
                    let result = PlanWriteback.merge(planItems: snapshot, workout: workout)
                    if result.changed {
                        plan.items = result.newItems
                        plan.markDirty()
                        receipt = .init(planLocalId: plan.localId, planName: plan.name,
                                        diffs: result.diffs, snapshot: snapshot,
                                        workoutLocalId: workout.localId, appliedItems: plan.items)
                    }
                }
            }
        }
        return receipt
    }

    static func delete(_ workout: Workout,
                       in context: ModelContext,
                       persist: (ModelContext) throws -> Void = { try LocalModelSave.save($0) }) throws {
        materializeSubtreeForCommit(workout)
        try commit(workout, in: context, persist: persist) { workout.markDeleted() }
    }

    static func discard(_ workout: Workout,
                        in context: ModelContext,
                        persist: (ModelContext) throws -> Void = { try LocalModelSave.save($0) }) throws {
        materializeSubtreeForCommit(workout)
        try commit(workout, in: context, persist: persist) {
            workout.markDeleted()
        }
    }

    /// 提交前加载聚合子节点，避免撤销快照遇到未来 backing，或把未加载关系恢复成空集合。
    static func materializeSubtreeForCommit(_ workout: Workout) {
        for exercise in workout.exercises {
            _ = exercise.localId
            for set in exercise.sets { _ = set.localId }
        }
    }

    private static func cleanupIncompleteSets(in workout: Workout, context: ModelContext) {
        for exercise in workout.exercises {
            for set in exercise.sets where set.isDropSet {
                set.pruneEmptyDropSegments(keepAtLeastOne: false)
            }
            let incomplete = exercise.sets.filter { !$0.completed }
            for set in incomplete { context.delete(set) }
            exercise.sets.removeAll { !$0.completed }
        }
        let empty = workout.exercises.filter { $0.sets.isEmpty }
        for exercise in empty { context.delete(exercise) }
        workout.exercises.removeAll { $0.sets.isEmpty }
        workout.updateTrainingUnits(workout.trainingUnits)
    }

    private static func commit(_ workout: Workout,
                               in context: ModelContext,
                               persist: (ModelContext) throws -> Void,
                               mutation: () throws -> Void) throws {
        let exercises = workout.exercises
        let setsByExercise = exercises.map { ($0, $0.sets) }
        do {
            try LocalModelCommit.perform(in: context, persist: { context in
                #if DEBUG
                try UITestHooks.failFirstSaveIfNeeded("lifecycle")
                #endif
                try persist(context)
            }, mutation: mutation)
        } catch {
            let previousUndo = context.undoManager
            context.undoManager = nil
            defer { context.undoManager = previousUndo }
            // iOS17的撤销可能已恢复节点却遗漏级联删除的关系，需重连原聚合。
            for (exercise, sets) in setsByExercise { exercise.sets = sets }
            workout.exercises = exercises
            throw error
        }
    }
}
