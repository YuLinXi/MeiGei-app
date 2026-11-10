import Foundation
import SwiftData

/// 普通新建计划表单的初始值。计划列表空白新建用 `.blank`；历史训练另存由 `Workout.personalPlanSeed()` 生成。
/// 只是表单持有的值，保存前不插入任何 `WorkoutPlan`。按 `id` 判等，供 `navigationDestination(item:)` 使用。
struct PlanEditorSeed: Identifiable, Hashable {
    let id: UUID
    var name: String
    var note: String
    var items: [PlanItem]

    init(id: UUID = UUID(), name: String = "", note: String = "", items: [PlanItem] = []) {
        self.id = id
        self.name = name
        self.note = String(note.prefix(PlanNoteEditorSheet.limit))
        self.items = items
    }

    static var blank: PlanEditorSeed { PlanEditorSeed() }

    static func == (lhs: PlanEditorSeed, rhs: PlanEditorSeed) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

@MainActor extension Workout {
    /// 历史详情「另存为个人计划」的表单初始值：名称、整体备注与本次实际训练转换出的计划项。
    /// 只读取当前训练聚合；在用户点击入口时生成一次，避免视图重绘反复生成新身份。
    func personalPlanSeed() -> PlanEditorSeed {
        PlanEditorSeed(name: planTemplateDefaultName,
                       note: note ?? "",
                       items: planTemplateItems())
    }
}

enum PlanCreationError: LocalizedError, Equatable {
    /// 另存来源（历史训练）已失效：被删除或不再满足另存条件。
    case sourceUnavailable
    /// 本地保存失败，可重试。
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .sourceUnavailable: return "原训练记录已不可用，无法另存"
        case .saveFailed: return "保存失败，请重试"
        }
    }
}

enum PlanEditingError: LocalizedError {
    case sourceUnavailable

    var errorDescription: String? { "当前计划内容已变化，请重新打开后再编辑。" }
}

/// 一次新建计划表单的提交。
///
/// - 同一表单最多成功创建一个计划：成功后再次提交直接忽略（防连续点击）。
/// - 候选在独立 context 保存，只有 `persist` 成功才返回调用方 context 中的计划；
///   不触碰共享 context 的其他未保存编辑，失败后表单可重试。
/// - 新计划为私有普通计划：新身份、`pendingCreate` 信封、无 Fork／分享关联，追加到所选分组末尾。
@MainActor
final class PlanCreationSubmission {
    private(set) var createdPlan: WorkoutPlan?
    private var isSubmitting = false

    var hasCreated: Bool { createdPlan != nil }

    /// 完成页另存沿用同一提交防重入；只在该入口更新训练名称，失败恢复其原信封。
    func submitCompletedWorkout(_ workout: Workout,
                                name: String,
                                mode: WorkoutPlanMode,
                                groupId: UUID?,
                                in context: ModelContext,
                                persist: (ModelContext) throws -> Void = { try LocalModelSave.save($0) }) throws -> WorkoutPlan? {
        guard let sourceContext = workout.modelContext,
              !workout.isDeleted,
              !sourceContext.insertedModelsArray.contains(where: { $0 === workout }) else {
            throw PlanCreationError.sourceUnavailable
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var renamedEnvelope: (updatedAt: Date, syncStatusRaw: String)?
        let plan = try submit(name: trimmedName, note: workout.note ?? "", mode: mode, groupId: groupId,
                              items: workout.planTemplateItems(), in: context,
                              canCreate: { workout.modelContext != nil && !workout.isDeleted
                                  && workout.canOfferSaveAsPlanTemplate(alreadySaved: false) },
                              persist: { creationContext in
            let id = workout.localId
            let descriptor = FetchDescriptor<Workout>(predicate: #Predicate { $0.localId == id })
            guard let stored = try creationContext.fetch(descriptor).first,
                  !stored.isDeleted, stored.canOfferSaveAsPlanTemplate(alreadySaved: false) else {
                throw PlanCreationError.sourceUnavailable
            }
            stored.title = trimmedName
            stored.markDirty()
            #if DEBUG
            try UITestHooks.failFirstSaveIfNeeded("template")
            #endif
            try persist(creationContext)
            renamedEnvelope = (stored.updatedAt, stored.syncStatusRaw)
        })
        if let renamedEnvelope {
            workout.title = trimmedName
            workout.updatedAt = renamedEnvelope.updatedAt
            workout.syncStatusRaw = renamedEnvelope.syncStatusRaw
        }
        return plan
    }

    func submit(name: String,
                note: String,
                mode: WorkoutPlanMode,
                groupId: UUID?,
                items: [PlanItem],
                in context: ModelContext,
                canCreate: () -> Bool = { true },
                persist: (ModelContext) throws -> Void = { try LocalModelSave.save($0) }) throws -> WorkoutPlan? {
        guard createdPlan == nil, !isSubmitting else { return nil }
        isSubmitting = true
        defer { isSubmitting = false }
        guard canCreate() else { throw PlanCreationError.sourceUnavailable }

        let candidate = WorkoutPlan(name: name.trimmingCharacters(in: .whitespaces),
                                    note: PlanNoteEditorSheet.normalize(note),
                                    items: items,
                                    mode: mode,
                                    groupId: groupId,
                                    sortOrder: Self.nextSortOrder(in: groupId, context: context))
        let plan: WorkoutPlan
        do {
            plan = try LocalModelCommit.insert(candidate, in: context, persist: persist)
        } catch let error as PlanCreationError {
            throw error
        } catch {
            throw PlanCreationError.saveFailed(error.localizedDescription)
        }
        createdPlan = plan
        return plan
    }

    static func nextSortOrder(in groupId: UUID?, context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<WorkoutPlan>(
            predicate: #Predicate { $0.deletedAt == nil }
        )
        let sameGroup = (try? context.fetch(descriptor))?.filter { $0.groupId == groupId } ?? []
        return (sameGroup.map(\.sortOrder).max() ?? -1) + 1
    }
}
