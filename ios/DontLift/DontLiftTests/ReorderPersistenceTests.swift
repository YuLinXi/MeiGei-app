import Foundation
import SwiftData
import Testing
@testable import DontLift

@MainActor
struct ReorderPersistenceTests {
    enum Target: CaseIterable { case groups, plans, planItems, workoutUnits }
    private struct SaveFailure: Error {}

    @Test(arguments: Target.allCases)
    func failedReorderRestoresOnlyItsMutationAndRetryPersists(_ target: Target) throws {
        let fixture = try Fixture()
        let context = fixture.context
        let envelopes = fixture.roots.map(Envelope.init)
        let unitSnapshot = fixture.workout.trainingUnits
        let itemSnapshot = fixture.plans[0].items
        let identities = Dictionary(uniqueKeysWithValues: fixture.workout.exercises.map { ($0.localId, $0.persistentModelID) })
        // 与排序无关、尚未保存的输入不能被失败提交撤销。
        fixture.plans[1].note = "保留未保存备注"
        let set = try #require(fixture.workout.exercises.first?.sets.first)
        set.weightKg = 63.75
        let setID = set.persistentModelID

        #expect(throws: SaveFailure.self) {
            try fixture.apply(target, ids: fixture.ids(target).reversed(), persist: { _ in throw SaveFailure() })
        }
        #expect(fixture.ids(target) == fixture.originalIDs(target))
        #expect(fixture.roots.map(Envelope.init) == envelopes)
        #expect(fixture.workout.trainingUnits == unitSnapshot)
        #expect(fixture.plans[0].items == itemSnapshot)
        #expect(Dictionary(uniqueKeysWithValues: fixture.workout.exercises.map { ($0.localId, $0.persistentModelID) }) == identities)
        #expect(set.persistentModelID == setID && set.weightKg == 63.75)
        #expect(fixture.plans[1].note == "保留未保存备注")

        try fixture.apply(target, ids: fixture.originalIDs(target).reversed())
        #expect(fixture.ids(target) == fixture.originalIDs(target).reversed())
        #expect(fixture.indices(target) == [0, 1, 2])
        #expect(set.weightKg == 63.75 && fixture.plans[1].note == "保留未保存备注")
        let reread = ModelContext(fixture.container)
        switch target {
        case .groups:
            let groups = try reread.fetch(FetchDescriptor<WorkoutPlanGroup>(sortBy: [SortDescriptor(\.sortOrder)]))
            #expect(groups.map(\.localId) == fixture.originalIDs(target).reversed())
            #expect(groups.allSatisfy { $0.syncStatus == .pendingUpdate })
        case .plans:
            let plans = try reread.fetch(FetchDescriptor<WorkoutPlan>(sortBy: [SortDescriptor(\.sortOrder)]))
            #expect(plans.map(\.localId) == fixture.originalIDs(target).reversed())
            #expect(plans.allSatisfy { $0.syncStatus == .pendingUpdate })
        case .planItems:
            let plans = try reread.fetch(FetchDescriptor<WorkoutPlan>())
            let plan = try #require(plans.first { $0.localId == fixture.plans[0].localId })
            #expect(plan.items.sorted { $0.orderIndex < $1.orderIndex }.map(\.itemId) == fixture.originalIDs(target).reversed())
            #expect(plan.syncStatus == .pendingUpdate)
            #expect(plan.items.first?.unitKind == itemSnapshot.last?.unitKind)
        case .workoutUnits:
            let workout = try #require(try reread.fetch(FetchDescriptor<Workout>()).first)
            #expect(workout.trainingUnits.map(\.unitId) == fixture.originalIDs(target).reversed())
            #expect(workout.exercises.sorted { $0.orderIndex < $1.orderIndex }.map(\.localId)
                    == [fixture.exercises[2].localId, fixture.exercises[3].localId,
                        fixture.exercises[1].localId, fixture.exercises[0].localId])
            #expect(workout.trainingUnits.first?.superset == unitSnapshot.last?.superset)
            #expect(fixture.plans[0].items == itemSnapshot, "当前训练排序不回写来源计划")
            #expect(workout.syncStatus == .pendingUpdate)
        }
    }

    @Test(arguments: Target.allCases)
    func unchangedDraftDoesNotSaveOrDirty(_ target: Target) throws {
        let fixture = try Fixture()
        let envelopes = fixture.roots.map(Envelope.init)
        var saves = 0
        try fixture.apply(target, ids: fixture.ids(target), persist: { _ in saves += 1 })
        #expect(saves == 0)
        #expect(fixture.roots.map(Envelope.init) == envelopes)
    }

    @Test(arguments: Target.allCases)
    func staleDraftSkipsRemovedIDsAndKeepsNewItems(_ target: Target) throws {
        let fixture = try Fixture()
        let ids = fixture.ids(target)
        // 未知身份是已移除项；第三项是面板打开后新增、未在草稿中的项。
        try fixture.apply(target, ids: [ids[1], UUID(), ids[0], ids[1]])
        #expect(fixture.ids(target) == [ids[1], ids[0], ids[2]])
        #expect(fixture.indices(target) == [0, 1, 2])
    }

    @Test func realReadonlyStoreRestoresPlanAndWorkoutOrder() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "ReorderFailure-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "readonly.store")
        let writable = try ModelContainer(for: AppModelContainer.schema,
            configurations: [ModelConfiguration(schema: AppModelContainer.schema, url: url, cloudKitDatabase: .none)])
        let fixture = try Fixture(container: writable)
        let readonly = try ModelContainer(for: AppModelContainer.schema,
            configurations: [ModelConfiguration(schema: AppModelContainer.schema, url: url,
                                                 allowsSave: false, cloudKitDatabase: .none)])
        let context = readonly.mainContext
        context.autosaveEnabled = false
        let plan = try #require(try context.fetch(FetchDescriptor<WorkoutPlan>()).first { $0.localId == fixture.plans[0].localId })
        let workout = try #require(try context.fetch(FetchDescriptor<Workout>()).first)
        let items = plan.items
        let units = workout.trainingUnits
        let planEnvelope = Envelope(plan)
        let workoutEnvelope = Envelope(workout)
        #expect(throws: (any Error).self) {
            try ReorderPersistence.planItems(plan, orderedIDs: items.map(\.itemId).reversed(), in: context)
        }
        #expect(plan.items == items && Envelope(plan) == planEnvelope)
        #expect(throws: (any Error).self) {
            try ReorderPersistence.workoutUnits(workout, orderedIDs: units.map(\.unitId).reversed(), in: context)
        }
        #expect(workout.trainingUnits == units && Envelope(workout) == workoutEnvelope)
        #expect(workout.exercises.sorted { $0.orderIndex < $1.orderIndex }.map(\.orderIndex) == [0, 1, 2, 3])
        withExtendedLifetime(fixture) {}
    }

    private struct Envelope: Equatable {
        let updatedAt: Date
        let status: String
        let version: Int
        let serverID: UUID?
        let deletedAt: Date?
        init(_ root: any Syncable) {
            updatedAt = root.updatedAt; status = root.syncStatusRaw; version = root.version
            serverID = root.serverId; deletedAt = root.deletedAt
        }
    }

    @MainActor private struct Fixture {
        let container: ModelContainer
        var context: ModelContext { container.mainContext }
        let groups: [WorkoutPlanGroup]
        let plans: [WorkoutPlan]
        let workout: Workout
        let exercises: [WorkoutExercise]
        let initial: [[UUID]]
        var roots: [any Syncable] { groups.map { $0 as any Syncable } + plans.map { $0 as any Syncable } + [workout] }

        init(container: ModelContainer = AppModelContainer.make(inMemory: true)) throws {
            self.container = container
            container.mainContext.autosaveEnabled = false
            groups = (0..<3).map { WorkoutPlanGroup(name: "分组\($0)", sortOrder: $0) }
            let items = [PlanItem(exerciseName: "卧推", orderIndex: 0),
                         .dropSet(orderIndex: 1, builtinExerciseCode: "BB_BENCH_PRESS", exerciseName: "递减卧推", groupCount: 2,
                                  segments: [WorkoutSetSegment(segmentIndex: 0, weightKg: 60, reps: 8)]),
                         .superset(orderIndex: 2, roundCount: 3, restAfterRoundSeconds: 90, members: [
                            PlanSupersetMember(builtinExerciseCode: "BB_ROW", exerciseName: "划船", orderIndex: 0,
                                               suggestedWeightKg: 50, suggestedReps: 10),
                            PlanSupersetMember(builtinExerciseCode: "DB_SHOULDER_PRESS", exerciseName: "推肩", orderIndex: 1,
                                               suggestedWeightKg: 15, suggestedReps: 12)])]
            plans = (0..<3).map { WorkoutPlan(name: "计划\($0)", items: $0 == 0 ? items : [], sortOrder: $0) }
            exercises = (0..<4).map { WorkoutExercise(exerciseName: "动作\($0)", orderIndex: $0,
                                                      sets: [WorkoutSet(setIndex: 0, weightKg: 60, reps: 8)]) }
            workout = Workout(planId: plans[0].localId, exercises: exercises)
            workout.updateTrainingUnits([
                WorkoutUnit(kind: .singleExercise, orderIndex: 0, singleExerciseId: exercises[0].localId),
                WorkoutUnit(kind: .dropSet, orderIndex: 1, singleExerciseId: exercises[1].localId),
                WorkoutUnit(kind: .superset, orderIndex: 2, superset: WorkoutSupersetUnit(roundCount: 3, restAfterRoundSeconds: 90,
                    members: [WorkoutSupersetMember(exerciseId: exercises[2].localId, orderIndex: 0),
                              WorkoutSupersetMember(exerciseId: exercises[3].localId, orderIndex: 1)]))
            ])
            groups.forEach { container.mainContext.insert($0) }
            plans.forEach { container.mainContext.insert($0) }
            container.mainContext.insert(workout)
            initial = [groups.map(\.localId), plans.map(\.localId), items.map(\.itemId), workout.trainingUnits.map(\.unitId)]
            for root in roots {
                root.serverId = root.localId; root.syncStatus = .synced
            }
            try container.mainContext.save()
        }

        func originalIDs(_ target: Target) -> [UUID] {
            switch target { case .groups: initial[0]; case .plans: initial[1]; case .planItems: initial[2]; case .workoutUnits: initial[3] }
        }
        func ids(_ target: Target) -> [UUID] {
            switch target {
            case .groups: groups.sorted { $0.sortOrder < $1.sortOrder }.map(\.localId)
            case .plans: plans.sorted { $0.sortOrder < $1.sortOrder }.map(\.localId)
            case .planItems: plans[0].items.sorted { $0.orderIndex < $1.orderIndex }.map(\.itemId)
            case .workoutUnits: workout.trainingUnits.map(\.unitId)
            }
        }
        func indices(_ target: Target) -> [Int] {
            switch target {
            case .groups: groups.map(\.sortOrder).sorted()
            case .plans: plans.map(\.sortOrder).sorted()
            case .planItems: plans[0].items.sorted { $0.orderIndex < $1.orderIndex }.map(\.orderIndex)
            case .workoutUnits: workout.trainingUnits.map(\.orderIndex)
            }
        }
        func apply(_ target: Target, ids: [UUID], persist: (ModelContext) throws -> Void = { try $0.save() }) throws {
            switch target {
            case .groups: try ReorderPersistence.groups(groups.sorted { $0.sortOrder < $1.sortOrder }, orderedIDs: ids, in: context, persist: persist)
            case .plans: try ReorderPersistence.plans(plans.sorted { $0.sortOrder < $1.sortOrder }, orderedIDs: ids, in: context, persist: persist)
            case .planItems: try ReorderPersistence.planItems(plans[0], orderedIDs: ids, in: context, persist: persist)
            case .workoutUnits: try ReorderPersistence.workoutUnits(workout, orderedIDs: ids, in: context, persist: persist)
            }
        }
    }
}
