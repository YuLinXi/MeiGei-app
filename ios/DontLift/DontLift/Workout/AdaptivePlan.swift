import Foundation
import SwiftUI
import SwiftData

// MARK: - 计划项归并 key（与 WorkoutExercise.historyKey 同公式）

extension PlanItem {
    /// 按动作归并的稳定 key：内置 code 优先，其次自定义 id，最后回退动作名。
    /// 自适应回写去重、开始训练历史回填均复用此 key。
    var historyKey: String { builtinExerciseCode ?? customExerciseId?.uuidString ?? exerciseName }
}

// MARK: - 开始训练落值（task 4.x）

/// 从计划生成今日训练时，按模式为每个计划项落值出 `WorkoutSet`（design.md D1/D4）。
/// 严格模式：整组复制计划预设。自适应模式：历史优先（上次同序号 completed 实绩）→ 回退计划预设。
enum PlanPrefill {
    /// 严格模式要求每个动作都有组数与次数；开始训练和切换模式都应复用同一校验。
    static func missingStrictRequiredItems(in items: [PlanItem]) -> [PlanItem] {
        items.filter { ($0.suggestedSets ?? 0) <= 0 || $0.suggestedReps == nil }
    }

    static func strictRequirementMessage(for missing: [PlanItem]) -> String {
        "严格模式开始训练前，请先补齐这些动作的组数与次数：" + missing.map(\.exerciseName).joined(separator: "、")
    }

    /// 历史里某动作「上次」已完成正式组的逐组 `(重量, 次数)`，按 setIndex 升序；无则空。
    /// 取最近一个含该 key 且有完成正式组的 finished workout。
    static func lastCompletedSets(forHistoryKey key: String, in history: [Workout]) -> [(weightKg: Double?, reps: Int?)] {
        let finished = history.filter { $0.isFinished }.sorted { $0.startedAt > $1.startedAt }
        for w in finished {
            for ex in w.exercises where ex.historyKey == key {
                let done = ex.sets.filter { $0.countsForStats }.sorted { $0.setIndex < $1.setIndex }
                if !done.isEmpty { return done.map { ($0.weightKg, $0.reps) } }
            }
        }
        return []
    }

    /// 为一个计划项生成开始训练时的落值组。新建组一律 `completed=false`。
    static func sets(for item: PlanItem, mode: WorkoutPlanMode, history: [Workout]) -> [WorkoutSet] {
        if mode == .strict {
            guard let count = item.suggestedSets, count > 0, item.suggestedReps != nil else { return [] }
            return (0..<count).map {
                WorkoutSet(setIndex: $0, weightKg: item.suggestedWeightKg, reps: item.suggestedReps)
            }
        }

        let last = (mode == .adaptive)
            ? lastCompletedSets(forHistoryKey: item.historyKey, in: history)
            : []
        // 自适应组数：计划 suggestedSets 优先；无 suggestedSets 时退回历史组数；再无则默认 4。
        let count = max(1, item.suggestedSets ?? (last.isEmpty ? PlanDefaults.suggestedSets : last.count))
        return (0..<count).map { idx in
            if mode == .adaptive, idx < last.count {
                // 自适应历史优先：用上次同序号 completed 实绩落值。
                return WorkoutSet(setIndex: idx, weightKg: last[idx].weightKg, reps: last[idx].reps)
            }
            // 自适应超出历史的组 / 无历史：用计划预设落值（可能为 nil 即留空）。
            return WorkoutSet(setIndex: idx, weightKg: item.suggestedWeightKg, reps: item.suggestedReps)
        }
    }
}

// MARK: - 自适应回写合并器（task 5.2）

/// 把一次已完成训练的实绩 upsert 回写到计划项（design.md D4）。纯逻辑、可单测。
/// 规则：动作只增不减（新增 append / 跳过保留）、组数只增不减（max）、重量次数如实写回（顶组代表值）。
enum PlanWriteback {
    enum DiffKind { case updated, added, kept }

    struct ItemDiff: Identifiable {
        let id = UUID()
        let kind: DiffKind
        let exerciseName: String
        /// 改值前摘要（仅 updated 有）。
        let oldText: String?
        /// 改值后 / 新增摘要（updated/added 有）。
        let newText: String?
    }

    struct Result {
        let newItems: [PlanItem]
        let diffs: [ItemDiff]
        /// 是否产生了实际改动（有 updated/added）；无改动则不回写、不弹回执。
        var changed: Bool { diffs.contains { $0.kind != .kept } }
    }

    /// 计划项强度摘要：`组×次×重kg`，缺省段省略。
    static func summary(_ i: PlanItem) -> String {
        var parts: [String] = []
        if let s = i.suggestedSets { parts.append("\(s) 组") }
        if let r = i.suggestedReps { parts.append("\(r) 次") }
        if let w = i.suggestedWeightKg { parts.append("\(formatKg(w)) kg") }
        return parts.isEmpty ? "未设建议" : parts.joined(separator: " × ")
    }

    /// 合并。仅依据本次 `completed` 正式组（`countsForStats`）。
    static func merge(planItems: [PlanItem], workout: Workout) -> Result {
        var items = planItems.sorted { $0.orderIndex < $1.orderIndex }
        var diffs: [ItemDiff] = []
        var touchedItemIds = Set<UUID>()          // 被 UPDATE 命中的原计划项 itemId
        var nextOrder = (items.map(\.orderIndex).max() ?? -1) + 1

        for ex in workout.exercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            let working = ex.sets.filter { $0.countsForStats }     // completed 正式组
            guard !working.isEmpty else { continue }               // 本次没做/没完成 → 不回写该动作
            // 顶组：最大重量那一组（nil 重量当 0）。
            guard let top = working.max(by: { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) }) else { continue }
            let setCount = working.count

            // 匹配：planItemId 优先，否则按 historyKey 去重（覆盖「先删再手动加回」）。
            let matchIdx = items.firstIndex { item in
                if let pid = ex.planItemId, item.itemId == pid { return true }
                return item.historyKey == ex.historyKey
            }

            if let idx = matchIdx {
                let before = summary(items[idx])
                items[idx].suggestedSets = max(items[idx].suggestedSets ?? 0, setCount)  // 组数只增不减
                items[idx].suggestedWeightKg = top.weightKg                              // 重量如实
                items[idx].suggestedReps = top.reps                                      // 次数如实
                touchedItemIds.insert(items[idx].itemId)
                let after = summary(items[idx])
                if after != before {
                    diffs.append(ItemDiff(kind: .updated, exerciseName: ex.exerciseName,
                                          oldText: before, newText: after))
                }
            } else {
                let newItem = PlanItem(itemId: UUID(),
                                       builtinExerciseCode: ex.builtinExerciseCode,
                                       customExerciseId: ex.customExerciseId,
                                       exerciseName: ex.exerciseName,
                                       orderIndex: nextOrder,
                                       suggestedSets: setCount,
                                       suggestedReps: top.reps,
                                       suggestedWeightKg: top.weightKg)
                nextOrder += 1
                items.append(newItem)
                diffs.append(ItemDiff(kind: .added, exerciseName: ex.exerciseName,
                                      oldText: nil, newText: summary(newItem)))
            }
        }

        // kept：原计划里有、本次未被 UPDATE 命中的项（保留不动，仅作回执展示）。
        for original in planItems where !touchedItemIds.contains(original.itemId) {
            diffs.append(ItemDiff(kind: .kept, exerciseName: original.exerciseName,
                                  oldText: nil, newText: nil))
        }

        return Result(newItems: items, diffs: diffs)
    }
}

// MARK: - 回写回执承载器（task 6.4，复刻 PRCelebrationCenter 模式）

/// 自适应回写回执的 App 级承载器（注入根环境）。结束训练会触发导航把进行中页换成只读详情，
/// 故把回执提到稳定不被销毁的 `MainTabView` 统一呈现，并提供「撤销」入口。
@Observable
final class PlanWritebackCenter {
    struct Receipt {
        let planLocalId: UUID
        let planName: String
        let diffs: [PlanWriteback.ItemDiff]
        /// 回写前计划项快照，供撤销还原。
        let snapshot: [PlanItem]
    }

    /// 待展示的回执；非 nil 即弹出回执 sheet。
    var receipt: Receipt?

    func present(_ r: Receipt) { receipt = r }
}

// MARK: - 回写回执 sheet（task 6.4）

/// 「已根据本次训练更新『X』计划」逐项 diff + 撤销入口。
struct PlanWritebackSheet: View {
    let receipt: PlanWritebackCenter.Receipt
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private var changed: [PlanWriteback.ItemDiff] { receipt.diffs.filter { $0.kind != .kept } }
    private var kept: [PlanWriteback.ItemDiff] { receipt.diffs.filter { $0.kind == .kept } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule().fill(Theme.Color.border2)
                .frame(width: 38, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10).padding(.bottom, 16)

            Text("已更新计划")
                .font(Theme.Font.mono(size: 10, weight: .bold))
                .tracking(0.2 * 10).textCase(.uppercase)
                .foregroundStyle(Theme.Color.accent)
            Text("「\(receipt.planName)」")
                .font(Theme.Font.display(size: 20, weight: .heavy))
                .foregroundStyle(Theme.Color.fg)
                .padding(.top, 4)

            VStack(spacing: 0) {
                ForEach(Array(changed.enumerated()), id: \.element.id) { idx, d in
                    if idx > 0 { Rectangle().fill(Theme.Color.border).frame(height: 1) }
                    row(d)
                }
            }
            .padding(.top, 18)

            if !kept.isEmpty {
                Text("已保留未训练的 \(kept.count) 个动作（需手动删除）")
                    .font(Theme.Font.body(size: 12))
                    .foregroundStyle(Theme.Color.muted)
                    .padding(.top, 14)
            }

            HStack(spacing: 12) {
                Button { undo() } label: {
                    Text("撤销此次更新")
                        .font(Theme.Font.display(size: 15, weight: .bold))
                        .foregroundStyle(Theme.Color.fg)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(Theme.Color.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.Color.border, lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
                Button { dismiss() } label: {
                    Text("好")
                        .font(Theme.Font.display(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(.top, 20)
        }
        .padding(.horizontal, 20).padding(.bottom, 26)
        .presentationBackground(Theme.Color.surface)
        .presentationCornerRadius(26)
        .presentationDragIndicator(.hidden)
        .presentationDetents([.medium])
    }

    @ViewBuilder private func row(_ d: PlanWriteback.ItemDiff) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(d.exerciseName)
                    .font(Theme.Font.display(size: 15, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                if d.kind == .updated, let o = d.oldText, let n = d.newText {
                    Text("\(o) → \(n)")
                        .font(Theme.Font.body(size: 12))
                        .foregroundStyle(Theme.Color.muted)
                } else if d.kind == .added, let n = d.newText {
                    Text(n).font(Theme.Font.body(size: 12)).foregroundStyle(Theme.Color.muted)
                }
            }
            Spacer(minLength: 0)
            Text(d.kind == .added ? "新增" : "更新")
                .font(Theme.Font.mono(size: 10, weight: .bold))
                .tracking(0.06 * 10).textCase(.uppercase)
                .foregroundStyle(Theme.Color.accent)
        }
        .padding(.vertical, 12)
    }

    /// 撤销：把计划项还原至回写前快照并标脏（重新同步该还原）。
    private func undo() {
        let plans = (try? modelContext.fetch(FetchDescriptor<WorkoutPlan>())) ?? []
        if let p = plans.first(where: { $0.localId == receipt.planLocalId }) {
            p.items = receipt.snapshot
            p.markDirty()
            try? modelContext.save()
        }
        dismiss()
    }
}
