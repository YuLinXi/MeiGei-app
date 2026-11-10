import Foundation
import SwiftData
import Testing
@testable import DontLift

@MainActor
struct PlanWritebackReceiptTests {
    private struct SaveFailure: Error {}

    @Test func generatedReceiptSurvivesImmediateSheetDismissal() throws {
        let f = try Fixture()
        let center = PlanWritebackCenter()
        #expect(f.receipt.workoutLocalId == f.workout.localId)
        #expect(f.receipt.appliedItems == f.plan.items)
        center.present(f.receipt)
        center.receipt = nil
        #expect(center.retainedReceipt(for: f.workout.localId)?.snapshot == f.original)
        #expect(center.retainedReceipt(for: UUID()) == nil)
    }

    @Test func undoRestoresPrescriptionsKeepsLaterNoteAndRemovesRetainedEntry() throws {
        let f = try Fixture()
        let center = PlanWritebackCenter()
        center.present(f.receipt)
        f.plan.note = "后来填写、尚未保存的备注"
        try PlanWriteback.undo(f.receipt, in: f.context)
        center.didUndo(f.receipt)
        #expect(f.plan.items == f.original)
        #expect(f.plan.note == "后来填写、尚未保存的备注")
        #expect(center.retainedReceipt(for: f.workout.localId) == nil)
        let loaded = try #require(try ModelContext(f.container).fetch(FetchDescriptor<WorkoutPlan>()).first)
        #expect(loaded.items == f.original && loaded.note == f.plan.note)
    }

    @Test func newerPlanItemsCannotBeOverwrittenByOldReceipt() throws {
        let f = try Fixture()
        var newer = f.plan.items
        newer[0].suggestedWeightKg = 90
        f.plan.items = newer
        f.plan.markDirty()
        try f.context.save()
        let updatedAt = f.plan.updatedAt
        let status = f.plan.syncStatusRaw
        #expect(throws: PlanWriteback.UndoError.planChanged) {
            try PlanWriteback.undo(f.receipt, in: f.context)
        }
        #expect(f.plan.items == newer)
        #expect(f.plan.updatedAt == updatedAt && f.plan.syncStatusRaw == status)
    }

    @Test func failedUndoKeepsAppliedValuesReceiptAndOtherPendingEditsForRetry() throws {
        let f = try Fixture()
        let center = PlanWritebackCenter()
        center.present(f.receipt)
        let applied = f.plan.items
        let updatedAt = f.plan.updatedAt
        let status = f.plan.syncStatusRaw
        f.plan.note = "失败也保留备注"
        #expect(throws: SaveFailure.self) {
            try PlanWriteback.undo(f.receipt, in: f.context, persist: { _ in throw SaveFailure() })
        }
        #expect(f.plan.items == applied && f.plan.note == "失败也保留备注")
        #expect(f.plan.updatedAt == updatedAt && f.plan.syncStatusRaw == status)
        #expect(center.retainedReceipt(for: f.workout.localId) != nil)
        try PlanWriteback.undo(f.receipt, in: f.context)
        center.didUndo(f.receipt)
        #expect(f.plan.items == f.original && f.plan.note == "失败也保留备注")
        #expect(center.retainedReceipt(for: f.workout.localId) == nil)
    }

    @Test func retentionIsBoundToLatestWorkoutAndCanResetForSessionChange() throws {
        let first = try Fixture()
        let second = try Fixture()
        let center = PlanWritebackCenter()
        center.present(first.receipt)
        center.present(second.receipt)
        #expect(center.retainedReceipt(for: first.workout.localId) == nil)
        #expect(center.retainedReceipt(for: second.workout.localId) != nil)
        center.didUndo(first.receipt)
        #expect(center.retainedReceipt(for: second.workout.localId) != nil)
        center.clearRetainedReceipt()
        #expect(center.retainedReceipt(for: second.workout.localId) == nil)
        #expect(center.receipt?.workoutLocalId == second.workout.localId, "清理保留值不抢占正在呈现的回执")
    }

    @MainActor private struct Fixture {
        let container: ModelContainer
        let context: ModelContext
        let plan: WorkoutPlan
        let workout: Workout
        let original: [PlanItem]
        let receipt: PlanWritebackCenter.Receipt

        init() throws {
            let container = AppModelContainer.make(inMemory: true)
            let context = container.mainContext
            context.autosaveEnabled = false
            let item = PlanItem(builtinExerciseCode: "BB_BENCH_PRESS", exerciseName: "杠铃卧推", orderIndex: 0,
                                suggestedSets: 2, suggestedReps: 8, suggestedWeightKg: 60)
            let plan = WorkoutPlan(name: "回执计划", items: [item])
            let exercise = WorkoutExercise(builtinExerciseCode: "BB_BENCH_PRESS", exerciseName: "杠铃卧推", orderIndex: 0,
                                           planItemId: item.itemId,
                                           sets: (0..<2).map { WorkoutSet(setIndex: $0, weightKg: 70, reps: 10, completed: true) })
            let workout = Workout(planId: plan.localId, exercises: [exercise])
            context.insert(plan)
            context.insert(workout)
            try context.save()
            let original = plan.items
            let receipt = try #require(try WorkoutPersistence.finish(workout, in: context, bodyWeightKg: nil))
            self.container = container
            self.context = context
            self.plan = plan
            self.workout = workout
            self.original = original
            self.receipt = receipt
        }
    }
}
