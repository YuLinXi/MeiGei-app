import Foundation
import SwiftData
import Testing
@testable import DontLift

@MainActor
struct LocalModelCommitTests {
    private struct InjectedSaveError: Error {}

    @Test func failedExistingCommitDoesNotPersistWhenAutosaveIsEnabled() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        context.autosaveEnabled = true
        let plan = WorkoutPlan(name: "原计划")
        context.insert(plan)
        try context.save()

        #expect(throws: InjectedSaveError.self) {
            try LocalModelCommit.perform(in: context, persist: { _ in throw InjectedSaveError() }) {
                plan.name = "失败的改名"
            }
        }

        #expect(context.autosaveEnabled)
        #expect(plan.name == "原计划")
        let stored = try #require(try ModelContext(container).fetch(FetchDescriptor<WorkoutPlan>()).first)
        #expect(stored.name == "原计划")
    }

    @Test func failedPlanConfigurationRestoresValuesAndKeepsOtherEdits() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        context.autosaveEnabled = false
        let items = [PlanItem(exerciseName: "卧推", orderIndex: 0, suggestedSets: 3,
                               suggestedReps: 8, suggestedWeightKg: 60)]
        let plan = WorkoutPlan(name: "原计划", items: items)
        let other = WorkoutPlan(name: "其他计划")
        context.insert(plan)
        context.insert(other)
        try context.save()
        let before = (plan.mode, plan.groupId, plan.updatedAt, plan.syncStatusRaw)
        other.note = "尚未保存的其他输入"
        let groupId = UUID()
        let edit = {
            plan.mode = .strict
            plan.groupId = groupId
            var revised = plan.items
            revised[0].suggestedWeightKg = 72.5
            plan.items = revised
            plan.markDirty()
        }
        #expect(throws: InjectedSaveError.self) {
            try LocalModelCommit.perform(in: context, persist: { _ in throw InjectedSaveError() }, mutation: edit)
        }
        #expect(plan.mode == before.0 && plan.groupId == before.1)
        #expect(plan.items == items)
        #expect(plan.updatedAt == before.2 && plan.syncStatusRaw == before.3)
        #expect(other.note == "尚未保存的其他输入")
        try LocalModelCommit.perform(in: context, mutation: edit)
        let reread = try #require(try ModelContext(container).fetch(FetchDescriptor<WorkoutPlan>()).first { $0.localId == plan.localId })
        #expect(reread.mode == .strict && reread.groupId == groupId)
        #expect(reread.items.first?.suggestedWeightKg == 72.5)
        #expect(reread.items.first?.itemId == items.first?.itemId)
    }

    @Test func failedGroupDeletionRestoresMembershipAndRetryMovesPlans() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        context.autosaveEnabled = false
        let group = WorkoutPlanGroup(name: "胸背", sortOrder: 0)
        let plans = [WorkoutPlan(name: "A", groupId: group.localId), WorkoutPlan(name: "B", groupId: group.localId)]
        context.insert(group)
        plans.forEach { context.insert($0) }
        try context.save()
        let groupId = group.localId
        let original = plans.map { ($0.updatedAt, $0.syncStatusRaw) }
        let remove = {
            for plan in plans { plan.groupId = nil; plan.markDirty() }
            group.markDeleted()
        }
        #expect(throws: InjectedSaveError.self) {
            try LocalModelCommit.perform(in: context, persist: { _ in throw InjectedSaveError() }, mutation: remove)
        }
        #expect(group.deletedAt == nil)
        #expect(plans.allSatisfy { $0.groupId == groupId })
        for (index, plan) in plans.enumerated() {
            #expect(plan.updatedAt == original[index].0 && plan.syncStatusRaw == original[index].1)
        }
        try LocalModelCommit.perform(in: context, mutation: remove)
        #expect(group.deletedAt != nil && group.syncStatus == .pendingDelete)
        #expect(try ModelContext(container).fetch(FetchDescriptor<WorkoutPlan>()).allSatisfy { $0.groupId == nil })
    }

    @Test func failedNewGroupLeavesNoCandidateAndRetryCreatesOne() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let candidate = WorkoutPlanGroup(name: "新分组", sortOrder: 0)
        #expect(throws: InjectedSaveError.self) {
            try LocalModelCommit.insert(candidate, in: context, persist: { _ in throw InjectedSaveError() })
        }
        #expect(try context.fetchCount(FetchDescriptor<WorkoutPlanGroup>()) == 0)
        let saved = try LocalModelCommit.insert(WorkoutPlanGroup(name: "新分组", sortOrder: 0), in: context)
        #expect(saved.modelContext === context)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<WorkoutPlanGroup>()) == 1)
    }

    @Test(arguments: 0..<10) func realReadonlyPlanAndGroupInsertionLeaveNoCandidate(attempt: Int) throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "PlanRootFailure-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "readonly.store")
        let writable = try store(url: url, allowsSave: true)
        let original = WorkoutPlan(name: "原计划")
        writable.mainContext.insert(original)
        try writable.mainContext.save()
        let readonly = try store(url: url, allowsSave: false)
        let context = readonly.mainContext
        context.autosaveEnabled = false
        let loaded = try #require(try context.fetch(FetchDescriptor<WorkoutPlan>()).first)
        loaded.note = "尚未保存的其他备注"
        #expect(throws: (any Error).self) {
            try LocalModelCommit.insert(WorkoutPlan(name: "副本", forkedFrom: original.localId), in: context)
        }
        #expect(throws: (any Error).self) {
            try LocalModelCommit.insert(WorkoutPlanGroup(name: "新分组", sortOrder: 0), in: context)
        }
        #expect(try context.fetch(FetchDescriptor<WorkoutPlan>()).map(\.localId) == [original.localId])
        #expect(try context.fetchCount(FetchDescriptor<WorkoutPlanGroup>()) == 0)
        #expect(loaded.note == "尚未保存的其他备注")
        #expect(try ModelContext(writable).fetchCount(FetchDescriptor<WorkoutPlan>()) == 1)
        #expect(try ModelContext(writable).fetchCount(FetchDescriptor<WorkoutPlanGroup>()) == 0)
        withExtendedLifetime(writable) {}
    }

    @Test func realReadonlyPlanSaveRestoresModeAndPrescription() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "PlanCommitFailure-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "readonly.store")
        let writable = try store(url: url, allowsSave: true)
        let plan = WorkoutPlan(name: "原计划", items: [PlanItem(exerciseName: "卧推", orderIndex: 0)])
        writable.mainContext.insert(plan)
        try writable.mainContext.save()
        let readonly = try store(url: url, allowsSave: false)
        let context = readonly.mainContext
        context.autosaveEnabled = false
        let loaded = try #require(try context.fetch(FetchDescriptor<WorkoutPlan>()).first)
        let original = (loaded.mode, loaded.items)
        #expect(throws: (any Error).self) {
            try LocalModelCommit.perform(in: context) {
                loaded.mode = .strict
                loaded.items = []
                loaded.markDirty()
            }
        }
        #expect(loaded.mode == original.0 && loaded.items == original.1)
        withExtendedLifetime(writable) {}
    }

    private func store(url: URL, allowsSave: Bool) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: AppModelContainer.schema, url: url,
                                               allowsSave: allowsSave, cloudKitDatabase: .none)
        return try ModelContainer(for: AppModelContainer.schema, configurations: [configuration])
    }
}
