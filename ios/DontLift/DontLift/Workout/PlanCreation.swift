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

/// 一次新建计划表单的提交。
///
/// - 同一表单最多成功创建一个计划：成功后再次提交直接忽略（防连续点击）。
/// - 只有 `persist` 成功才返回计划；失败时只撤回本次插入的候选计划，
///   不回滚整个共享 context，避免丢弃其他未保存编辑；表单可重试。
/// - 新计划为私有普通计划：新身份、`pendingCreate` 信封、无 Fork／分享关联，追加到所选分组末尾。
@MainActor
final class PlanCreationSubmission {
    private(set) var createdPlan: WorkoutPlan?
    private var isSubmitting = false

    var hasCreated: Bool { createdPlan != nil }

    func submit(name: String,
                note: String,
                mode: WorkoutPlanMode,
                groupId: UUID?,
                items: [PlanItem],
                in context: ModelContext,
                canCreate: () -> Bool = { true },
                persist: (ModelContext) throws -> Void = { try $0.save() }) throws -> WorkoutPlan? {
        guard createdPlan == nil, !isSubmitting else { return nil }
        isSubmitting = true
        defer { isSubmitting = false }
        guard canCreate() else { throw PlanCreationError.sourceUnavailable }

        let plan = WorkoutPlan(name: name.trimmingCharacters(in: .whitespaces),
                               note: PlanNoteEditorSheet.normalize(note),
                               items: items,
                               mode: mode,
                               groupId: groupId,
                               sortOrder: Self.nextSortOrder(in: groupId, context: context))
        context.insert(plan)
        do {
            try persist(context)
        } catch {
            context.delete(plan)
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
