import Foundation
import SwiftData
import Testing
@testable import DontLift

@MainActor
struct PlanWritebackUndoTests {
    private struct SaveFailure: Error {}

    @Test func failedUndoKeepsCurrentPlanAndOtherEditsThenRetryRestoresSnapshot() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        context.autosaveEnabled = false
        let original = PlanItem(exerciseName: "卧推", orderIndex: 0, suggestedSets: 3, suggestedReps: 8, suggestedWeightKg: 60)
        var revised = original
        revised.suggestedWeightKg = 65
        let plan = WorkoutPlan(name: "训练计划", items: [revised])
        let other = WorkoutPlan(name: "其他计划")
        context.insert(plan)
        context.insert(other)
        try context.save()
        let metadata = (plan.updatedAt, plan.syncStatusRaw)
        other.note = "保留其他编辑"
        let receipt = PlanWritebackCenter.Receipt(planLocalId: plan.localId, planName: plan.name,
                                                 diffs: [], snapshot: [original])
        #expect(throws: SaveFailure.self) {
            try PlanWriteback.undo(receipt, in: context, persist: { _ in throw SaveFailure() })
        }
        #expect(plan.items == [revised])
        #expect(plan.updatedAt == metadata.0 && plan.syncStatusRaw == metadata.1)
        #expect(other.note == "保留其他编辑")
        try PlanWriteback.undo(receipt, in: context)
        let saved = try #require(try ModelContext(container).fetch(FetchDescriptor<WorkoutPlan>()).first { $0.localId == plan.localId })
        #expect(saved.items == [original])
        #expect(saved.items.first?.itemId == revised.itemId)
    }

    @Test func missingOrDeletedPlanCannotPretendUndoSucceeded() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let plan = WorkoutPlan(name: "已删除计划")
        context.insert(plan)
        plan.markDeleted()
        try context.save()
        for id in [UUID(), plan.localId] {
            let receipt = PlanWritebackCenter.Receipt(planLocalId: id, planName: plan.name, diffs: [], snapshot: [])
            #expect(throws: PlanWriteback.UndoError.self) { try PlanWriteback.undo(receipt, in: context) }
        }
    }

    @Test func readonlyUndoPreservesCurrentPrescription() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "WritebackUndo-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "readonly.store")
        let writable = try store(url, allowsSave: true)
        let original = PlanItem(exerciseName: "卧推", orderIndex: 0, suggestedWeightKg: 60)
        var revised = original
        revised.suggestedWeightKg = 65
        let plan = WorkoutPlan(name: "原计划", items: [revised])
        writable.mainContext.insert(plan)
        try writable.mainContext.save()
        let readonly = try store(url, allowsSave: false)
        let context = readonly.mainContext
        context.autosaveEnabled = false
        let loaded = try #require(try context.fetch(FetchDescriptor<WorkoutPlan>()).first)
        let receipt = PlanWritebackCenter.Receipt(planLocalId: loaded.localId, planName: loaded.name,
                                                 diffs: [], snapshot: [original])
        #expect(throws: (any Error).self) { try PlanWriteback.undo(receipt, in: context) }
        #expect(loaded.items == [revised])
        withExtendedLifetime(writable) {}
    }

    private func store(_ url: URL, allowsSave: Bool) throws -> ModelContainer {
        try ModelContainer(for: AppModelContainer.schema, configurations: [
            ModelConfiguration(schema: AppModelContainer.schema, url: url, allowsSave: allowsSave, cloudKitDatabase: .none)
        ])
    }
}
