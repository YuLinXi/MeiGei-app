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

    /// 历史里某计划项「上次」已完成正式组的逐组 `(重量, 次数)`，按 setIndex 升序；无则空。
    /// 新数据优先用 `planItemId` 精确匹配，旧数据才退回无 `planItemId` 的 `historyKey` 匹配。
    static func lastCompletedSets(for item: PlanItem, in history: [Workout]) -> [(weightKg: Double?, reps: Int?)] {
        let exact = lastCompletedSets(in: history) { $0.planItemId == item.itemId }
        if !exact.isEmpty { return exact }
        return lastCompletedSets(forHistoryKey: item.historyKey, in: history)
    }

    static func lastCompletedSets(for item: PlanItem, in lookup: PlanHistoryLookup) -> [(weightKg: Double?, reps: Int?)] {
        lookup.latestSets(for: item).map { ($0.weightKg, $0.reps) }
    }

    /// 历史里某动作「上次」已完成正式组的逐组 `(重量, 次数)`，按 setIndex 升序；无则空。
    /// 仅匹配无 `planItemId` 的旧记录，避免重复同动作计划项互相串味。
    static func lastCompletedSets(forHistoryKey key: String, in history: [Workout]) -> [(weightKg: Double?, reps: Int?)] {
        lastCompletedSets(in: history) { $0.planItemId == nil && $0.historyKey == key }
    }

    private static func lastCompletedSets(in history: [Workout], matching matches: (WorkoutExercise) -> Bool) -> [(weightKg: Double?, reps: Int?)] {
        let finished = history.filter { $0.isFinished }.sorted { $0.startedAt > $1.startedAt }
        for w in finished {
            for ex in w.exercises where matches(ex) {
                let done = ex.sets.filter { $0.countsForStats }.sorted { $0.setIndex < $1.setIndex }
                if !done.isEmpty { return done.map { ($0.weightKg, $0.reps) } }
            }
        }
        return []
    }

    /// 历史里某动作最近一次 completed 正式组所在训练日期；供计划详情展示来源说明。
    static func lastCompletedWorkoutDate(for item: PlanItem, in history: [Workout]) -> Date? {
        if let exact = lastCompletedWorkoutDate(in: history, matching: { $0.planItemId == item.itemId }) {
            return exact
        }
        return lastCompletedWorkoutDate(forHistoryKey: item.historyKey, in: history)
    }

    /// 历史里某动作最近一次 completed 正式组所在训练日期；仅匹配无 `planItemId` 的旧记录。
    static func lastCompletedWorkoutDate(forHistoryKey key: String, in history: [Workout]) -> Date? {
        lastCompletedWorkoutDate(in: history) { $0.planItemId == nil && $0.historyKey == key }
    }

    private static func lastCompletedWorkoutDate(in history: [Workout], matching matches: (WorkoutExercise) -> Bool) -> Date? {
        let finished = history.filter { $0.isFinished }.sorted { $0.startedAt > $1.startedAt }
        for w in finished {
            for ex in w.exercises where matches(ex) {
                if ex.sets.contains(where: { $0.countsForStats }) { return w.startedAt }
            }
        }
        return nil
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
            ? lastCompletedSets(for: item, in: history)
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

    static func sets(for item: PlanItem, mode: WorkoutPlanMode, lookup: PlanHistoryLookup) -> [WorkoutSet] {
        if mode == .strict {
            guard let count = item.suggestedSets, count > 0, item.suggestedReps != nil else { return [] }
            return (0..<count).map {
                WorkoutSet(setIndex: $0, weightKg: item.suggestedWeightKg, reps: item.suggestedReps)
            }
        }

        let last = mode == .adaptive ? lastCompletedSets(for: item, in: lookup) : []
        let count = max(1, item.suggestedSets ?? (last.isEmpty ? PlanDefaults.suggestedSets : last.count))
        return (0..<count).map { idx in
            if mode == .adaptive, idx < last.count {
                return WorkoutSet(setIndex: idx, weightKg: last[idx].weightKg, reps: last[idx].reps)
            }
            return WorkoutSet(setIndex: idx, weightKg: item.suggestedWeightKg, reps: item.suggestedReps)
        }
    }
}

// MARK: - 下次训练处方预览（task 6.9）

/// 计划详情页展示的「下次有效处方」。它用 `PlanPrefill.sets` 生成预览组，
/// 保证页面所见与点击「开始这次训练」后的实际落值一致。
struct PlanPrescriptionPreview {
    enum Source: Equatable {
        case strict
        case history(Date)
        case planPreset
        case defaultValue
        case kept(Date)

        var badgeText: String {
            switch self {
            case .strict: "严格模式"
            case .history: "历史"
            case .planPreset: "预设"
            case .defaultValue: "默认"
            case .kept: "保留"
            }
        }

        var detailText: String {
            switch self {
            case .strict:
                "严格模式 · 完成后不更新"
            case .history(let date):
                "来自上次完成 · \(date.formatted(.relative(presentation: .named)))"
            case .planPreset:
                "计划预设"
            case .defaultValue:
                "默认起步"
            case .kept:
                "上次未练 · 已保留"
            }
        }
    }

    let sets: [WorkoutSet]
    let source: Source

    var badgeText: String { source.badgeText }
    var detailText: String { source.detailText }

    var summaryText: String {
        guard !sets.isEmpty else { return "缺少组数/次数" }
        let countText = "下次 \(sets.count) 组"
        guard let representative = representativeSet else { return countText }

        switch (representative.weightKg, representative.reps) {
        case let (.some(weight), .some(reps)):
            return "\(countText) · \(formatKg(weight)) kg × \(reps)"
        case let (.some(weight), .none):
            return "\(countText) · \(formatKg(weight)) kg"
        case let (.none, .some(reps)):
            return "\(countText) × \(reps)"
        case (.none, .none):
            return countText
        }
    }

    /// 用最重组作为摘要代表；无重量时取第一组有次数的组。
    private var representativeSet: WorkoutSet? {
        let weighted = sets.filter { $0.weightKg != nil }
        if !weighted.isEmpty {
            return weighted.max { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) }
        }
        return sets.first { $0.reps != nil } ?? sets.first
    }

    static func make(for item: PlanItem, mode: WorkoutPlanMode, history: [Workout], planId: UUID? = nil) -> PlanPrescriptionPreview {
        let sets = PlanPrefill.sets(for: item, mode: mode, history: history)
        if mode == .strict {
            return PlanPrescriptionPreview(sets: sets, source: .strict)
        }

        let source: Source
        if let keptDate = lastPlanWorkoutSkippedDate(for: item, in: history, planId: planId) {
            source = .kept(keptDate)
        } else if let historyDate = PlanPrefill.lastCompletedWorkoutDate(for: item, in: history) {
            source = .history(historyDate)
        } else if item.suggestedSets != nil {
            source = .planPreset
        } else {
            source = .defaultValue
        }
        return PlanPrescriptionPreview(sets: sets, source: source)
    }

    static func make(for item: PlanItem, mode: WorkoutPlanMode, lookup: PlanHistoryLookup, planId: UUID? = nil) -> PlanPrescriptionPreview {
        let sets = PlanPrefill.sets(for: item, mode: mode, lookup: lookup)
        if mode == .strict {
            return PlanPrescriptionPreview(sets: sets, source: .strict)
        }

        let source: Source
        if let keptDate = lookup.keptDate(for: item, planId: planId) {
            source = .kept(keptDate)
        } else if let historyDate = lookup.latestDate(for: item) {
            source = .history(historyDate)
        } else if item.suggestedSets != nil {
            source = .planPreset
        } else {
            source = .defaultValue
        }
        return PlanPrescriptionPreview(sets: sets, source: source)
    }

    /// 最近一次同计划训练里没完成该动作时，展示「保留」心智。
    private static func lastPlanWorkoutSkippedDate(for item: PlanItem, in history: [Workout], planId: UUID?) -> Date? {
        guard let planId else { return nil }
        guard let lastPlanWorkout = history
            .filter({ $0.isFinished && $0.planId == planId })
            .max(by: { $0.startedAt < $1.startedAt }) else { return nil }

        let didComplete = lastPlanWorkout.exercises.contains { ex in
            let matchesItem: Bool
            if let planItemId = ex.planItemId {
                matchesItem = planItemId == item.itemId
            } else {
                matchesItem = ex.historyKey == item.historyKey
            }
            return matchesItem && ex.sets.contains(where: { $0.countsForStats })
        }
        return didComplete ? nil : lastPlanWorkout.startedAt
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

            // 匹配：planItemId 精确优先；缺失/找不到时，仅在 historyKey 命中唯一项时 fallback。
            let matchIdx = matchIndex(for: ex, in: items)

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

    private static func matchIndex(for ex: WorkoutExercise, in items: [PlanItem]) -> Int? {
        if let pid = ex.planItemId, let exact = items.firstIndex(where: { $0.itemId == pid }) {
            return exact
        }
        let fallbackMatches = items.indices.filter { items[$0].historyKey == ex.historyKey }
        return fallbackMatches.count == 1 ? fallbackMatches[0] : nil
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
    @State private var contentHeight: CGFloat = 360

    private var changed: [PlanWriteback.ItemDiff] { receipt.diffs.filter { $0.kind != .kept } }
    private var kept: [PlanWriteback.ItemDiff] { receipt.diffs.filter { $0.kind == .kept } }
    private var changedListMaxHeight: CGFloat { min(CGFloat(max(changed.count, 1)) * 72, 320) }

    var body: some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: PlanWritebackSheetHeightKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(PlanWritebackSheetHeightKey.self) { height in
                guard abs(contentHeight - height) > 0.5 else { return }
                contentHeight = height
            }
            .frame(maxWidth: .infinity)
            .presentationBackground(Theme.Color.surface)
            .presentationCornerRadius(26)
            .presentationDragIndicator(.hidden)
            .presentationDetents([.height(contentHeight)])
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule().fill(Theme.Color.border2)
                .frame(width: 38, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10).padding(.bottom, 16)

            Text("已更新计划")
                .font(Theme.Font.mono(size: 12, weight: .bold))
                .tracking(0.2 * 12).textCase(.uppercase)
                .foregroundStyle(Theme.Color.accent)
            Text("「\(receipt.planName)」")
                .font(Theme.Font.display(size: 26, weight: .heavy))
                .foregroundStyle(Theme.Color.fg)
                .padding(.top, 6)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(changed.enumerated()), id: \.element.id) { idx, d in
                        if idx > 0 { Rectangle().fill(Theme.Color.border).frame(height: 1) }
                        row(d)
                    }
                }
            }
            .scrollIndicators(.visible)
            .frame(maxHeight: changedListMaxHeight)
            .padding(.top, 18)

            if !kept.isEmpty {
                Text("已保留未训练的 \(kept.count) 个动作（需手动删除）")
                    .font(Theme.Font.body(size: 15))
                    .foregroundStyle(Theme.Color.muted)
                    .padding(.top, 16)
            }

            HStack(spacing: 12) {
                Button { undo() } label: {
                    Text("撤销此次更新")
                        .font(Theme.Font.display(size: 18, weight: .bold))
                        .foregroundStyle(Theme.Color.fg)
                        .frame(maxWidth: .infinity).padding(.vertical, 17)
                        .background(Theme.Color.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.Color.border, lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
                Button { dismiss() } label: {
                    Text("好")
                        .font(Theme.Font.display(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 17)
                        .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(.top, 20)
        }
        .padding(.horizontal, 24).padding(.bottom, 30)
    }

    @ViewBuilder private func row(_ d: PlanWriteback.ItemDiff) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(d.exerciseName)
                    .font(Theme.Font.display(size: 19, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                if d.kind == .updated, let o = d.oldText, let n = d.newText {
                    Text("\(o) → \(n)")
                        .font(Theme.Font.body(size: 15))
                        .foregroundStyle(Theme.Color.muted)
                } else if d.kind == .added, let n = d.newText {
                    Text(n).font(Theme.Font.body(size: 15)).foregroundStyle(Theme.Color.muted)
                }
            }
            Spacer(minLength: 0)
            Text(d.kind == .added ? "新增" : "更新")
                .font(Theme.Font.mono(size: 12, weight: .bold))
                .tracking(0.06 * 12).textCase(.uppercase)
                .foregroundStyle(Theme.Color.accent)
        }
        .padding(.vertical, 14)
    }

    /// 撤销：把计划项还原至回写前快照并标脏（重新同步该还原）。
    private func undo() {
        let planId = receipt.planLocalId
        var descriptor = FetchDescriptor<WorkoutPlan>(
            predicate: #Predicate {
                $0.localId == planId
            }
        )
        descriptor.fetchLimit = 1
        if let p = (try? modelContext.fetch(descriptor))?.first {
            p.items = receipt.snapshot
            p.markDirty()
            try? modelContext.save()
        }
        dismiss()
    }
}

/// 测量回写回执 sheet 内容自然高度，避免短内容落在固定 medium detent 中产生大块上下留白。
private struct PlanWritebackSheetHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
