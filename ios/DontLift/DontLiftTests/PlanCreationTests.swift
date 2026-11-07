import Foundation
import SwiftData
import Testing
@testable import DontLift

/// 历史训练另存为个人计划：表单初始值、独立创建、失败重试与 JSON 往返。
@MainActor
struct PlanCreationTests {
    private struct InjectedSaveError: Error {}

    // MARK: 2.1 表单初始值

    @Test func blankSeedStillCreatesEmptyPlan() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let seed = PlanEditorSeed.blank

        let plan = try #require(try PlanCreationSubmission().submit(
            name: "新计划", note: seed.note, mode: .adaptive, groupId: nil,
            items: seed.items, in: context))

        #expect(seed.name.isEmpty && seed.note.isEmpty && seed.items.isEmpty)
        #expect(plan.items.isEmpty)
        #expect(plan.mode == .adaptive)
        #expect(plan.groupId == nil)
    }

    @Test func historySeedPrefillsWithoutInsertingPlan() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let workout = sampleWorkout(planId: nil)
        context.insert(workout)
        try context.save()

        let seed = workout.personalPlanSeed()

        #expect(seed.name == "周二胸背")
        #expect(seed.note == "控制离心")
        #expect(seed.items.map(\.unitDisplayName) == ["卧推", "递减组 · 飞鸟", "下拉 + 弯举"])
        // 只打开表单（生成初始值）或取消都不插入计划。
        #expect(try context.fetchCount(FetchDescriptor<WorkoutPlan>()) == 0)
        #expect(!context.hasChanges)
    }

    @Test func historySeedUsesTemplateNameForGenericTitle() {
        let workout = sampleWorkout(planId: nil)
        workout.title = "训练"
        #expect(workout.personalPlanSeed().name == "训练模板")
    }

    @Test func basicInfoEditDoesNotRebuildItems() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let items = sampleWorkout(planId: nil).planTemplateItems()
        let plan = WorkoutPlan(name: "旧名", items: items)
        context.insert(plan)
        try context.save()

        PlanEditorView.applyBasicInfo(to: plan, name: " 新名 ", note: "备注", mode: .strict, groupId: nil)

        #expect(plan.name == "新名")
        #expect(plan.note == "备注")
        #expect(plan.mode == .strict)
        #expect(plan.items == items)
    }

    // MARK: 2.2 独立私有计划

    @Test func historySaveCreatesIndependentPrivatePlan() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let sourceItem = PlanItem(exerciseName: "卧推", orderIndex: 0, suggestedSets: 3,
                                  suggestedReps: 8, suggestedWeightKg: 80)
        let source = WorkoutPlan(name: "来源计划", items: [sourceItem], forkedFrom: UUID(),
                                 sharedToTeamId: UUID())
        let group = WorkoutPlanGroup(name: "推拉腿", sortOrder: 0)
        let groupMate = WorkoutPlan(name: "已有", groupId: group.localId, sortOrder: 3)
        let workout = sampleWorkout(planId: source.localId)
        workout.sourceShareId = UUID()
        workout.sourceShareVersionId = UUID()
        [source, groupMate].forEach { context.insert($0) }
        context.insert(group)
        context.insert(workout)
        for synced in [source, groupMate] as [any Syncable] {
            synced.syncStatusRaw = SyncStatus.synced.rawValue
        }
        workout.syncStatusRaw = SyncStatus.synced.rawValue
        try context.save()
        let workoutBefore = snapshot(workout)
        let sourceBefore = (source.name, source.items, source.updatedAt, source.syncStatusRaw, source.version)

        let seed = workout.personalPlanSeed()
        let plan = try #require(try PlanCreationSubmission().submit(
            name: "  胸背进阶 ", note: seed.note + "\n", mode: .adaptive, groupId: group.localId,
            items: seed.items, in: context))

        #expect(plan.name == "胸背进阶")
        #expect(plan.note == "控制离心")
        #expect(plan.groupId == group.localId)
        #expect(plan.sortOrder == 4)
        #expect(plan.localId != source.localId)
        #expect(Set(plan.items.map(\.itemId)).isDisjoint(with: source.items.map(\.itemId)))
        #expect(plan.syncStatus == .pendingCreate)
        #expect(plan.serverId == nil && plan.deletedAt == nil && plan.version == 0)
        #expect(plan.forkedFrom == nil && plan.forkedFromShareVersionId == nil && plan.sharedToTeamId == nil)

        #expect(snapshot(workout) == workoutBefore)
        #expect(source.name == sourceBefore.0)
        #expect(source.items == sourceBefore.1)
        #expect(source.updatedAt == sourceBefore.2)
        #expect(source.syncStatusRaw == sourceBefore.3)
        #expect(source.version == sourceBefore.4)
    }

    @Test func repeatedHistorySaveCreatesAnotherIndependentPlan() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let workout = sampleWorkout(planId: nil)
        context.insert(workout)
        try context.save()

        let first = try #require(try PlanCreationSubmission().submit(
            name: "A", note: "", mode: .adaptive, groupId: nil,
            items: workout.personalPlanSeed().items, in: context))
        let second = try #require(try PlanCreationSubmission().submit(
            name: "B", note: "", mode: .adaptive, groupId: nil,
            items: workout.personalPlanSeed().items, in: context))

        #expect(first.localId != second.localId)
        #expect(Set(first.items.map(\.itemId)).isDisjoint(with: second.items.map(\.itemId)))
        #expect(second.sortOrder == first.sortOrder + 1)
    }

    // MARK: 2.3 保存结果与重复提交

    @Test func failedSaveKeepsOtherEditsAndRetryCreatesSinglePlan() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let other = WorkoutPlan(name: "其他计划")
        context.insert(other)
        try context.save()
        other.name = "未保存的改名"
        let items = sampleWorkout(planId: nil).planTemplateItems()
        let submission = PlanCreationSubmission()
        var successCallbacks = 0

        #expect(throws: PlanCreationError.self) {
            if try submission.submit(name: "另存", note: "", mode: .adaptive, groupId: nil, items: items,
                                     in: context, persist: { _ in throw InjectedSaveError() }) != nil {
                successCallbacks += 1
            }
        }
        #expect(successCallbacks == 0)
        #expect(!submission.hasCreated)
        #expect(try context.fetch(FetchDescriptor<WorkoutPlan>()).map(\.name) == ["未保存的改名"])
        #expect(other.name == "未保存的改名")

        if try submission.submit(name: "另存", note: "", mode: .adaptive, groupId: nil, items: items,
                                 in: context) != nil {
            successCallbacks += 1
        }
        // 成功后再次提交（连续点击）不再创建。
        if try submission.submit(name: "另存", note: "", mode: .adaptive, groupId: nil, items: items,
                                 in: context) != nil {
            successCallbacks += 1
        }

        #expect(successCallbacks == 1)
        let reread = try ModelContext(container).fetch(FetchDescriptor<WorkoutPlan>())
        #expect(reread.filter { $0.name == "另存" }.count == 1)
        #expect(reread.contains { $0.name == "未保存的改名" })
    }

    @Test func invalidSourceIsNotSaved() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let submission = PlanCreationSubmission()

        #expect(throws: PlanCreationError.sourceUnavailable) {
            _ = try submission.submit(name: "另存", note: "", mode: .adaptive, groupId: nil,
                                      items: sampleWorkout(planId: nil).planTemplateItems(),
                                      in: context, canCreate: { false })
        }
        #expect(try context.fetchCount(FetchDescriptor<WorkoutPlan>()) == 0)
        #expect(!submission.hasCreated)
    }

    // MARK: 2.4 JSON 往返与离线

    @Test func savedPlanSurvivesJSONAndLocalRoundTripAndSourceDeletion() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let workout = sampleWorkout(planId: nil)
        context.insert(workout)
        try context.save()
        let seed = workout.personalPlanSeed()
        let plan = try #require(try PlanCreationSubmission().submit(
            name: seed.name, note: seed.note, mode: .adaptive, groupId: nil,
            items: seed.items, in: context))
        let planId = plan.localId

        // 与 SyncEngine 上传一致的 JSON 字符串编解码。
        let json = try #require(String(data: JSONCoding.encoder.encode(plan.items), encoding: .utf8))
        let decoded = try JSONCoding.decoder.decode([PlanItem].self, from: Data(json.utf8))
        #expect(decoded == seed.items)

        // 离线创建：本地待同步；随后删除原训练不影响新计划。
        context.delete(workout)
        try context.save()

        let reread = try #require(try ModelContext(container).fetch(
            FetchDescriptor<WorkoutPlan>(predicate: #Predicate { $0.localId == planId })).first)
        #expect(reread.syncStatus == .pendingCreate)
        #expect(reread.items == seed.items)
        #expect(reread.note == "控制离心")

        let bench = try #require(reread.items.first { $0.exerciseName == "卧推" })
        #expect(bench.orderedSetPrescriptions.map(\.weightKg) == [20, 60, 65, 70])
        #expect(bench.orderedSetPrescriptions.map(\.isWarmupEffective) == [true, false, false, false])
        #expect(bench.note == "顶峰收缩")
        #expect(bench.restAfterSetSeconds == nil)
        let drop = try #require(reread.items.first { $0.isDropSet })
        #expect(drop.dropSetPrescriptions.map { $0.segments.map(\.weightKg) } == [[80, 60], [75, 55, 40]])
        #expect(drop.restAfterSetSeconds == 0)
        let superset = try #require(reread.items.first { $0.isSuperset })
        #expect(superset.supersetRounds == 2)
        #expect(superset.supersetRestAfterRoundSeconds == 90)
        #expect(superset.orderedSupersetMembers.map(\.suggestedWeightKg) == [Double?](arrayLiteral: 55, 15))
        #expect(superset.note == "不休息")
    }

    // MARK: 3.3 另存计划的后续使用

    @Test func savedPlanStartsFromStaticTemplateOrAdaptiveHistory() throws {
        let items = sampleWorkout(planId: nil).planTemplateItems()
        let benchItem = try #require(items.first { $0.exerciseName == "卧推" })

        // 严格模式与无历史的自适应：按静态模板逐组落值（保留逐组差异与热身）。
        for (mode, lookup) in [(WorkoutPlanMode.strict, PlanHistoryLookup.empty), (.adaptive, .empty)] {
            let workout = PlanWorkoutBuilder.workout(title: "胸背进阶", items: items, mode: mode, lookup: lookup)
            let bench = try #require(workout.exercises.first { $0.exerciseName == "卧推" })
            let benchSets = bench.sets.sorted { $0.setIndex < $1.setIndex }
            #expect(benchSets.map(\.weightKg) == [20, 60, 65, 70])
            #expect(benchSets.map(\.reps) == [10, 10, 8, 6])
            #expect(benchSets.map(\.isWarmupEffective) == [true, false, false, false])
            let fly = try #require(workout.exercises.first { $0.exerciseName == "飞鸟" })
            #expect(fly.sets.sorted { $0.setIndex < $1.setIndex }.map { $0.effectiveSegments.map(\.weightKg) }
                    == [[80, 60], [75, 55, 40]])
            // 超级组仍按成员统一值落到每一轮。
            let pulldown = try #require(workout.exercises.first { $0.exerciseName == "下拉" })
            let curl = try #require(workout.exercises.first { $0.exerciseName == "弯举" })
            #expect(pulldown.sets.map(\.weightKg) == [Double?](repeating: 55, count: 2))
            #expect(curl.sets.map(\.reps) == [Int?](repeating: 12, count: 2))
        }

        // 自适应模式存在更新的同动作历史时，动态安排以历史优先，静态模板本身不变。
        let newer = LatestExercisePerformance(date: Date(timeIntervalSince1970: 1_900_000_000),
                                              sets: [SetSnapshot(weightKg: 100, reps: 5)])
        let lookup = PlanHistoryLookup(latestByPlanExercise: [:],
                                       latestByHistoryKey: [benchItem.historyKey: newer],
                                       lastWorkoutByPlanId: [:])
        let adaptive = PlanWorkoutBuilder.workout(title: "胸背进阶", items: items, mode: .adaptive, lookup: lookup)
        let bench = try #require(adaptive.exercises.first { $0.exerciseName == "卧推" })
        #expect(bench.sets.map(\.weightKg) == [100])
        #expect(benchItem.orderedSetPrescriptions.map(\.weightKg) == [20, 60, 65, 70])
    }

    // MARK: 样例

    /// 普通动作（热身 + 三组不同正式组 + 未完成组）、两个逻辑组不同的递减组、各轮不同的超级组。
    private func sampleWorkout(planId: UUID?) -> Workout {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let workout = Workout(planId: planId, title: "周二胸背", startedAt: startedAt,
                              endedAt: startedAt.addingTimeInterval(3600), note: "控制离心")
        let bench = WorkoutExercise(builtinExerciseCode: "BB_BENCH", exerciseName: "卧推", orderIndex: 0)
        bench.note = "顶峰收缩"
        bench.sets = [
            WorkoutSet(setIndex: 0, weightKg: 20, reps: 10, completed: true, setType: .warmup),
            WorkoutSet(setIndex: 1, weightKg: 60, reps: 10, completed: true, setType: .working),
            WorkoutSet(setIndex: 2, weightKg: 65, reps: 8, completed: true, setType: .working),
            WorkoutSet(setIndex: 3, weightKg: 70, reps: 6, completed: true, setType: .working),
            WorkoutSet(setIndex: 4, weightKg: 72.5, reps: 5, completed: false, setType: .working)
        ]
        let fly = WorkoutExercise(exerciseName: "飞鸟", orderIndex: 1)
        fly.sets = [
            WorkoutSet(setIndex: 0, completed: true, setType: .drop, segments: [
                WorkoutSetSegment(segmentIndex: 0, weightKg: 80, reps: 8),
                WorkoutSetSegment(segmentIndex: 1, weightKg: 60, reps: 6)
            ]),
            WorkoutSet(setIndex: 1, completed: true, setType: .drop, segments: [
                WorkoutSetSegment(segmentIndex: 0, weightKg: 75, reps: 7),
                WorkoutSetSegment(segmentIndex: 1, weightKg: 55, reps: 8),
                WorkoutSetSegment(segmentIndex: 2, weightKg: 40, reps: 10)
            ])
        ]
        let pulldown = WorkoutExercise(exerciseName: "下拉", orderIndex: 2)
        pulldown.sets = [
            WorkoutSet(setIndex: 0, weightKg: 50, reps: 12, completed: true, setType: .working),
            WorkoutSet(setIndex: 1, weightKg: 55, reps: 10, completed: true, setType: .working)
        ]
        let curl = WorkoutExercise(exerciseName: "弯举", orderIndex: 3)
        curl.sets = [
            WorkoutSet(setIndex: 0, weightKg: 12.5, reps: 15, completed: true, setType: .working),
            WorkoutSet(setIndex: 1, weightKg: 15, reps: 12, completed: true, setType: .working)
        ]
        workout.exercises = [bench, fly, pulldown, curl]
        workout.appendSingleExerciseUnit(for: bench, restAfterSetSeconds: nil)
        workout.appendDropSetUnit(for: fly, restAfterSetSeconds: 0)
        workout.appendSupersetUnit(first: pulldown, second: curl, roundCount: 2,
                                   restAfterRoundSeconds: 90, note: "不休息")
        return workout
    }

    private struct WorkoutSnapshot: Equatable {
        var title: String?
        var note: String?
        var planId: UUID?
        var sourceShareId: UUID?
        var sourceShareVersionId: UUID?
        var updatedAt: Date
        var syncStatusRaw: String
        var version: Int
        var unitsJSON: String?
        var sets: [String]
    }

    private func snapshot(_ workout: Workout) -> WorkoutSnapshot {
        WorkoutSnapshot(title: workout.title,
                        note: workout.note,
                        planId: workout.planId,
                        sourceShareId: workout.sourceShareId,
                        sourceShareVersionId: workout.sourceShareVersionId,
                        updatedAt: workout.updatedAt,
                        syncStatusRaw: workout.syncStatusRaw,
                        version: workout.version,
                        unitsJSON: workout.unitsJSON,
                        sets: workout.exercises.sorted { $0.orderIndex < $1.orderIndex }.flatMap { ex in
                            ex.sets.sorted { $0.setIndex < $1.setIndex }.map {
                                "\(ex.exerciseName)|\($0.setIndex)|\($0.weightKg ?? -1)|\($0.reps ?? -1)|\($0.completed)"
                            }
                        })
    }
}
