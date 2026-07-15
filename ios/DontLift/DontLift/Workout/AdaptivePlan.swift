import Foundation
import SwiftUI
import SwiftData

// MARK: - 计划项归并 key（与 WorkoutExercise.historyKey 同公式）

extension PlanItem {
    /// 按动作归并的稳定 key：内置 code 优先且归并到 canonical code，其次自定义 id，最后回退动作名。
    /// 自适应回写去重、开始训练历史回填均复用此 key。
    var historyKey: String {
        ExerciseLibrary.canonicalHistoryKey(
            code: builtinExerciseCode,
            name: exerciseName,
            customId: customExerciseId
        )
    }
}

// MARK: - 开始训练落值（task 4.x）

/// 从计划生成今日训练时，按模式为每个计划项落值出 `WorkoutSet`（design.md D1/D4）。
/// 严格模式：整组复制计划预设。自适应模式：历史优先（上次同序号 completed 实绩）→ 回退计划预设。
enum PlanPrefill {
    /// 严格模式要求每个动作都有组数与次数；开始训练和切换模式都应复用同一校验。
    static func missingStrictRequiredItems(in items: [PlanItem]) -> [PlanItem] {
        items.filter {
            if $0.isSuperset {
                return $0.supersetRounds <= 0 || $0.orderedSupersetMembers.contains { $0.suggestedReps == nil }
            }
            if $0.isDropSet {
                let prescriptions = startPrescriptions(for: $0)
                guard let drop = prescriptions.first else { return true }
                return drop.segments.allSatisfy { $0.weightKg == nil && $0.reps == nil }
            }
            if !$0.formalSetPrescriptions.isEmpty { return false }
            return ($0.suggestedSets ?? 0) <= 0 || $0.suggestedReps == nil
        }
    }

    static func strictRequirementMessage(for missing: [PlanItem]) -> String {
        "严格模式开始训练前，请先补齐这些动作的组数与次数：" + missing.map(\.displayExerciseName).joined(separator: "、")
    }

    /// 历史里某计划项「上次」已完成正式组的逐组 `(重量, 次数)`，按 setIndex 升序；无则空。
    /// 新数据优先用 `planItemId` 精确匹配，旧数据才退回无 `planItemId` 的 `historyKey` 匹配。
    static func lastCompletedSets(for item: PlanItem, in history: [Workout]) -> [(weightKg: Double?, reps: Int?)] {
        lastCompletedSnapshots(for: item, in: history).map { ($0.weightKg, $0.reps) }
    }

    static func lastCompletedSnapshots(for item: PlanItem, in history: [Workout]) -> [SetSnapshot] {
        let exact = lastCompletedSets(in: history, for: item) {
            $0.planItemId == item.itemId
                && $0.historyKey == item.historyKey
                && matchesPlanUnitKind($0, item: item)
        }
        if !exact.isEmpty { return exact }
        return lastCompletedSets(in: history, for: item) {
            $0.planItemId == nil && $0.historyKey == item.historyKey && matchesPlanUnitKind($0, item: item)
        }
    }

    static func lastCompletedSets(for item: PlanItem, in lookup: PlanHistoryLookup) -> [(weightKg: Double?, reps: Int?)] {
        lookup.latestSets(for: item).map { ($0.weightKg, $0.reps) }
    }

    static func lastCompletedSnapshots(for item: PlanItem, in lookup: PlanHistoryLookup) -> [SetSnapshot] {
        lookup.latestSets(for: item)
    }

    /// 历史里某动作「上次」已完成正式组的逐组 `(重量, 次数)`，按 setIndex 升序；无则空。
    /// 仅匹配无 `planItemId` 的旧记录，避免重复同动作计划项互相串味。
    static func lastCompletedSets(forHistoryKey key: String, in history: [Workout]) -> [(weightKg: Double?, reps: Int?)] {
        lastCompletedSnapshots(forHistoryKey: key, in: history).map { ($0.weightKg, $0.reps) }
    }

    static func lastCompletedSnapshots(forHistoryKey key: String, in history: [Workout]) -> [SetSnapshot] {
        lastCompletedStatSets(in: history) { $0.planItemId == nil && $0.historyKey == key }
    }

    private static func lastCompletedSets(in history: [Workout], for item: PlanItem, matching matches: (WorkoutExercise) -> Bool) -> [SetSnapshot] {
        let finished = history.filter { $0.isFinished }.sorted { $0.startedAt > $1.startedAt }
        for w in finished {
            for ex in w.exercises where matches(ex) {
                let done = completedExecutionSets(from: ex, for: item)
                if !done.isEmpty {
                    return done.map(snapshot(from:))
                }
            }
        }
        return []
    }

    private static func lastCompletedStatSets(in history: [Workout], matching matches: (WorkoutExercise) -> Bool) -> [SetSnapshot] {
        let finished = history.filter { $0.isFinished }.sorted { $0.startedAt > $1.startedAt }
        for w in finished {
            for ex in w.exercises where matches(ex) {
                let done = ex.sets.filter(\.countsForStats).sorted { $0.setIndex < $1.setIndex }
                if !done.isEmpty { return done.map(snapshot(from:)) }
            }
        }
        return []
    }

    static func completedExecutionSets(from exercise: WorkoutExercise, for item: PlanItem) -> [WorkoutSet] {
        let completed = exercise.sets.filter(\.completed)
        if item.isDropSet {
            return completed
                .filter { $0.isDropSet && !$0.isWarmupEffective }
                .sorted { $0.setIndex < $1.setIndex }
        }
        let regular = completed
            .filter { !$0.isDropSet }
            .sorted {
                if $0.isWarmupEffective != $1.isWarmupEffective {
                    return $0.isWarmupEffective && !$1.isWarmupEffective
                }
                return $0.setIndex < $1.setIndex
            }
        guard regular.contains(where: { !$0.isWarmupEffective }) else { return [] }
        return regular
    }

    static func snapshot(from set: WorkoutSet) -> SetSnapshot {
        let summary = set.summaryWeightReps
        return SetSnapshot(weightKg: summary.weightKg,
                           reps: summary.reps,
                           setTypeRaw: set.setTypeRaw,
                           isWarmup: set.isWarmupEffective,
                           segments: set.segments)
    }

    private static func matchesPlanUnitKind(_ exercise: WorkoutExercise, item: PlanItem) -> Bool {
        exercise.sets.contains { $0.isDropSet } == item.isDropSet
    }

    /// 历史里某动作最近一次 completed 正式组所在训练日期；供计划详情展示来源说明。
    static func lastCompletedWorkoutDate(for item: PlanItem, in history: [Workout]) -> Date? {
        if let exact = lastCompletedWorkoutDate(in: history, for: item, matching: {
            $0.planItemId == item.itemId
                && $0.historyKey == item.historyKey
                && matchesPlanUnitKind($0, item: item)
        }) {
            return exact
        }
        return lastCompletedWorkoutDate(in: history, for: item) {
            $0.planItemId == nil && $0.historyKey == item.historyKey && matchesPlanUnitKind($0, item: item)
        }
    }

    /// 历史里某动作最近一次 completed 正式组所在训练日期；仅匹配无 `planItemId` 的旧记录。
    static func lastCompletedWorkoutDate(forHistoryKey key: String, in history: [Workout]) -> Date? {
        let finished = history.filter { $0.isFinished }.sorted { $0.startedAt > $1.startedAt }
        for w in finished {
            for ex in w.exercises where ex.planItemId == nil && ex.historyKey == key {
                if ex.sets.contains(where: { $0.countsForStats }) { return w.startedAt }
            }
        }
        return nil
    }

    private static func lastCompletedWorkoutDate(in history: [Workout],
                                                 for item: PlanItem,
                                                 matching matches: (WorkoutExercise) -> Bool) -> Date? {
        let finished = history.filter { $0.isFinished }.sorted { $0.startedAt > $1.startedAt }
        for w in finished {
            for ex in w.exercises where matches(ex) {
                if !completedExecutionSets(from: ex, for: item).isEmpty { return w.startedAt }
            }
        }
        return nil
    }

    /// 为一个计划项生成开始训练时的落值组。新建组一律 `completed=false`。
    static func sets(for item: PlanItem, mode: WorkoutPlanMode, history: [Workout]) -> [WorkoutSet] {
        guard !item.isSuperset else { return [] }
        if mode == .strict {
            let prescriptions = startPrescriptions(for: item)
            if !prescriptions.isEmpty { return sets(from: prescriptions) }
            guard let count = item.suggestedSets, count > 0, item.suggestedReps != nil else { return [] }
            return legacySets(for: item, count: count)
        }

        let last = (mode == .adaptive)
            ? lastCompletedSnapshots(for: item, in: history)
            : []
        if !last.isEmpty { return sets(from: last) }
        let prescriptions = startPrescriptions(for: item)
        if !prescriptions.isEmpty { return sets(from: prescriptions) }
        let count = max(1, item.suggestedSets ?? PlanDefaults.suggestedSets)
        return legacySets(for: item, count: count)
    }

    static func sets(for item: PlanItem, mode: WorkoutPlanMode, lookup: PlanHistoryLookup) -> [WorkoutSet] {
        guard !item.isSuperset else { return [] }
        if mode == .strict {
            let prescriptions = startPrescriptions(for: item)
            if !prescriptions.isEmpty { return sets(from: prescriptions) }
            guard let count = item.suggestedSets, count > 0, item.suggestedReps != nil else { return [] }
            return legacySets(for: item, count: count)
        }

        let last = mode == .adaptive ? lastCompletedSnapshots(for: item, in: lookup) : []
        if !last.isEmpty { return sets(from: last) }
        let prescriptions = startPrescriptions(for: item)
        if !prescriptions.isEmpty { return sets(from: prescriptions) }
        let count = max(1, item.suggestedSets ?? PlanDefaults.suggestedSets)
        return legacySets(for: item, count: count)
    }

    /// 训练中切换候选的落值：严格模式不读历史；自适应仅读同动作位下该实际动作的历史。
    static func replacementSets(planItemId: UUID,
                                option: PlanExerciseOption,
                                unit: WorkoutUnit,
                                lookup: PlanHistoryLookup) -> [WorkoutSet] {
        let defaults = unit.defaultSetSnapshots ?? []
        guard !defaults.isEmpty else { return [] }
        let isDefault = unit.exerciseOptions?.first?.historyKey == option.historyKey

        if unit.planMode == .adaptive {
            let last = lookup.latestSets(planItemId: planItemId, historyKey: option.historyKey)
            if !last.isEmpty { return sets(from: last) }
        }

        return sets(from: isDefault ? defaults : weightless(defaults))
    }

    private static func startPrescriptions(for item: PlanItem) -> [PlanSetPrescription] {
        if item.isDropSet {
            let templates = item.dropSetPrescriptions
            guard let firstTemplate = templates.first else { return [] }
            let count = max(1, item.suggestedSets ?? templates.count, templates.count)
            return (0..<count).map { index in
                let template = templates.indices.contains(index) ? templates[index] : firstTemplate
                return PlanSetPrescription(prescriptionId: templates.indices.contains(index) ? template.prescriptionId : UUID(),
                                           setType: .drop,
                                           orderIndex: index,
                                           weightKg: template.weightKg,
                                           reps: template.reps,
                                           isWarmup: false,
                                           segments: template.segments
                                            .sorted { $0.segmentIndex < $1.segmentIndex }
                                            .enumerated()
                                            .map { segmentIndex, segment in
                                                WorkoutSetSegment(segmentId: templates.indices.contains(index) ? segment.segmentId : UUID(),
                                                                  segmentIndex: segmentIndex,
                                                                  weightKg: segment.weightKg,
                                                                  reps: segment.reps)
                                            })
            }
        }
        let regular = item.regularSetPrescriptions
        guard !regular.isEmpty else { return [] }
        if item.formalSetPrescriptions.isEmpty,
           let count = item.suggestedSets,
           count > 0 {
            return PlanItem.reindexRegularPrescriptions(
                item.warmupSetPrescriptions + legacyPrescriptions(for: item, count: count)
            )
        }
        return PlanItem.reindexRegularPrescriptions(regular)
    }

    private static func legacySets(for item: PlanItem, count: Int) -> [WorkoutSet] {
        (0..<count).map {
            WorkoutSet(setIndex: $0, weightKg: item.suggestedWeightKg, reps: item.suggestedReps)
        }
    }

    private static func legacyPrescriptions(for item: PlanItem, count: Int) -> [PlanSetPrescription] {
        (0..<count).map {
            PlanSetPrescription(orderIndex: $0,
                                weightKg: item.suggestedWeightKg,
                                reps: item.suggestedReps)
        }
    }

    private static func sets(from prescriptions: [PlanSetPrescription]) -> [WorkoutSet] {
        prescriptions.enumerated().map { idx, prescription in
            let type = prescription.setType
            let segments = normalizedSegments(prescription.segments)
            return WorkoutSet(setIndex: idx,
                              weightKg: prescription.weightKg,
                              reps: prescription.reps,
                              setType: type,
                              isWarmup: type == .drop ? false : prescription.isWarmupEffective,
                              segments: type == .drop ? segments : [])
        }
    }

    static func sets(from snapshots: [SetSnapshot]) -> [WorkoutSet] {
        snapshots.enumerated().map { idx, snapshot in
            let type = WorkoutSetType(rawValue: snapshot.setTypeRaw) ?? .working
            let segments = normalizedSegments(snapshot.segments)
            return WorkoutSet(setIndex: idx,
                              weightKg: snapshot.weightKg,
                              reps: snapshot.reps,
                              setType: type,
                              isWarmup: snapshot.isWarmup,
                              segments: type == .drop ? segments : [])
        }
    }

    private static func weightless(_ snapshots: [SetSnapshot]) -> [SetSnapshot] {
        snapshots.map { snapshot in
            SetSnapshot(weightKg: nil,
                        reps: snapshot.reps,
                        setTypeRaw: snapshot.setTypeRaw,
                        isWarmup: snapshot.isWarmup,
                        segments: snapshot.segments.map { segment in
                            WorkoutSetSegment(segmentId: segment.segmentId,
                                              segmentIndex: segment.segmentIndex,
                                              weightKg: nil,
                                              reps: segment.reps)
                        })
        }
    }

    private static func normalizedSegments(_ segments: [WorkoutSetSegment]) -> [WorkoutSetSegment] {
        segments.sorted { $0.segmentIndex < $1.segmentIndex }
            .enumerated()
            .map { idx, segment in
                WorkoutSetSegment(segmentId: segment.segmentId,
                                  segmentIndex: idx,
                                  weightKg: segment.weightKg,
                                  reps: segment.reps)
            }
    }
}

enum PlanWorkoutBuilder {
    static func workout(from plan: WorkoutPlan, lookup: PlanHistoryLookup) -> Workout {
        let workout = workout(title: plan.name,
                              items: plan.items,
                              mode: plan.mode,
                              lookup: lookup)
        workout.planId = plan.localId
        return workout
    }

    static func workout(title: String?,
                        items: [PlanItem],
                        mode: WorkoutPlanMode,
                        lookup: PlanHistoryLookup) -> Workout {
        let workout = Workout(title: title)
        var exerciseOrder = 0
        for item in items.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            if item.isSuperset {
                appendSuperset(from: item, to: workout, exerciseOrder: &exerciseOrder)
                continue
            }
            let exercise = WorkoutExercise(builtinExerciseCode: item.builtinExerciseCode,
                                           customExerciseId: item.customExerciseId,
                                           exerciseName: item.displayExerciseName,
                                           primaryMuscle: item.resolvedPrimaryMuscle,
                                           orderIndex: exerciseOrder,
                                           planItemId: item.itemId)
            exercise.sets = PlanPrefill.sets(for: item, mode: mode, lookup: lookup)
            workout.exercises.append(exercise)
            if item.isDropSet {
                workout.appendDropSetUnit(for: exercise)
            } else {
                let options = item.exerciseOptions
                workout.appendSingleExerciseUnit(
                    for: exercise,
                    exerciseOptions: options.isEmpty ? nil : options,
                    planMode: options.isEmpty ? nil : mode,
                    defaultSetSnapshots: options.isEmpty ? nil : exercise.sets
                        .sorted { $0.setIndex < $1.setIndex }
                        .map(PlanPrefill.snapshot(from:))
                )
            }
            exerciseOrder += 1
        }
        return workout
    }

    private static func appendSuperset(from item: PlanItem, to workout: Workout, exerciseOrder: inout Int) {
        let members = item.orderedSupersetMembers
        guard members.count == 2 else { return }
        let first = workoutExercise(from: members[0], orderIndex: exerciseOrder)
        first.sets = supersetSets(rounds: item.supersetRounds, member: members[0])
        exerciseOrder += 1

        let second = workoutExercise(from: members[1], orderIndex: exerciseOrder)
        second.sets = supersetSets(rounds: item.supersetRounds, member: members[1])
        exerciseOrder += 1

        workout.exercises.append(first)
        workout.exercises.append(second)
        workout.appendSupersetUnit(first: first,
                                   second: second,
                                   roundCount: item.supersetRounds,
                                   restAfterRoundSeconds: item.supersetRestAfterRoundSeconds)
    }

    private static func workoutExercise(from member: PlanSupersetMember, orderIndex: Int) -> WorkoutExercise {
        WorkoutExercise(builtinExerciseCode: member.builtinExerciseCode,
                        customExerciseId: member.customExerciseId,
                        exerciseName: member.displayExerciseName,
                        primaryMuscle: member.resolvedPrimaryMuscle,
                        orderIndex: orderIndex,
                        planItemId: member.memberId)
    }

    private static func supersetSets(rounds: Int, member: PlanSupersetMember) -> [WorkoutSet] {
        (0..<max(1, rounds)).map {
            WorkoutSet(setIndex: $0,
                       weightKg: member.suggestedWeightKg,
                       reps: member.suggestedReps,
                       setType: .working)
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
        guard !mainSets.isEmpty else { return "缺少正式组" }
        let countText = sets.contains(where: \.isWarmupEffective)
            ? "下次 \(previewSetCount) 正式组"
            : "下次 \(previewSetCount) 组"
        guard let representative = representativeSet else { return countText }
        let values = representative.summaryWeightReps
        let dropText = mainSets.contains(where: \.isDropSet) ? " · 含递减组" : ""

        switch (values.weightKg, values.reps) {
        case let (.some(weight), .some(reps)):
            return "\(countText) · \(formatKg(weight)) kg × \(reps)\(dropText)"
        case let (.some(weight), .none):
            return "\(countText) · \(formatKg(weight)) kg\(dropText)"
        case let (.none, .some(reps)):
            return "\(countText) × \(reps)\(dropText)"
        case (.none, .none):
            return "\(countText)\(dropText)"
        }
    }

    var warmupSummaryText: String? {
        let warmups = sets.filter(\.isWarmupEffective)
        guard !warmups.isEmpty else { return nil }
        let details = warmups.prefix(3).map(\.compactValueText).joined(separator: " / ")
        let suffix = warmups.count > 3 ? " …" : ""
        return "热身 \(warmups.count) 组 · \(details)\(suffix)"
    }

    /// 用最重组作为摘要代表；无重量时取第一组有次数的组。
    private var representativeSet: WorkoutSet? {
        let weighted = mainSets.filter { $0.summaryWeightReps.weightKg != nil }
        if !weighted.isEmpty {
            return weighted.max { ($0.summaryWeightReps.weightKg ?? 0) < ($1.summaryWeightReps.weightKg ?? 0) }
        }
        return mainSets.first { $0.summaryWeightReps.reps != nil } ?? mainSets.first
    }

    private var previewSetCount: Int {
        mainSets.count
    }

    private var mainSets: [WorkoutSet] {
        sets.filter { !$0.isWarmupEffective }
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
        if i.isSuperset {
            let memberText = i.orderedSupersetMembers.map { member in
                var parts: [String] = [member.displayExerciseName]
                if let reps = member.suggestedReps { parts.append("\(reps) 次") }
                if let weight = member.suggestedWeightKg { parts.append("\(formatKg(weight)) kg") }
                return parts.joined(separator: " · ")
            }.joined(separator: " / ")
            return "超级组 · \(i.supersetRounds) 组 · \(memberText)"
        }
        if i.isDropSet {
            var parts: [String] = ["递减组"]
            if let s = i.suggestedSets { parts.append("\(s) 组") }
            if let r = i.suggestedReps { parts.append("\(r) 次") }
            if let w = i.suggestedWeightKg { parts.append("\(formatKg(w)) kg") }
            return parts.joined(separator: " · ")
        }
        var parts: [String] = []
        if let s = i.suggestedSets { parts.append("\(s) 组") }
        if let r = i.suggestedReps { parts.append("\(r) 次") }
        if let w = i.suggestedWeightKg { parts.append("\(formatKg(w)) kg") }
        if i.orderedSetPrescriptions.contains(where: { $0.setType == .drop }) { parts.append("含递减组") }
        return parts.isEmpty ? "未设建议" : parts.joined(separator: " × ")
    }

    /// 合并。仅依据本次 `completed` 正式组（`countsForStats`）。
    static func merge(planItems: [PlanItem], workout: Workout) -> Result {
        var items = planItems.sorted { $0.orderIndex < $1.orderIndex }
        var diffs: [ItemDiff] = []
        var touchedItemIds = Set<UUID>()          // 被 UPDATE 命中的原计划项 itemId
        var nextOrder = (items.map(\.orderIndex).max() ?? -1) + 1
        let supersetExerciseIds = workout.supersetExerciseIds

        for ex in workout.exercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            if ex.planItemId == nil && supersetExerciseIds.contains(ex.localId) {
                continue
            }
            let working = ex.sets
                .filter { $0.countsForStats }
                .sorted { $0.setIndex < $1.setIndex }
            let isDropSetUnit = workout.dropSetExerciseIds.contains(ex.localId) || working.contains(where: \.isDropSet)

            if let target = supersetMemberTarget(for: ex, in: items) {
                guard let top = topStatEntry(in: working) else { continue }
                let before = summary(items[target.itemIndex])
                var item = items[target.itemIndex]
                var members = item.orderedSupersetMembers
                members[target.memberIndex].suggestedWeightKg = top.weightKg
                members[target.memberIndex].suggestedReps = top.reps
                item.supersetMembers = members
                items[target.itemIndex] = item
                touchedItemIds.insert(item.itemId)
                let after = summary(item)
                if after != before {
                    diffs.append(ItemDiff(kind: .updated, exerciseName: ex.exerciseName,
                                          oldText: before, newText: after))
                }
                continue
            }

            // 匹配：planItemId 精确优先；缺失/找不到时，仅在 historyKey 命中唯一项时 fallback。
            let matchIdx = matchIndex(for: ex, in: items, isDropSetUnit: isDropSetUnit)

            // 来自计划的实际动作与当前默认动作不同时，说明本次使用了备选（或计划在训练中被改过）。
            // 实绩由训练历史自然保留，但不得把另一动作的重量/次数覆盖到默认处方。
            if let idx = matchIdx,
               ex.planItemId != nil,
               ex.historyKey != items[idx].historyKey {
                guard !working.isEmpty else { continue }
                touchedItemIds.insert(items[idx].itemId)
                continue
            }
            let existingPrescriptions = matchIdx.map { items[$0].orderedSetPrescriptions } ?? []

            if isDropSetUnit {
                let dropSets = working.filter(\.isDropSet)
                guard !dropSets.isEmpty, let top = topStatEntry(in: dropSets) else { continue }
                let setCount = dropSets.count
                let existingDrops = existingPrescriptions.filter { $0.setType == .drop }
                let prescriptions = dropSets.enumerated().map { idx, set in
                    prescription(from: set,
                                 orderIndex: idx,
                                 existing: existingDrops.indices.contains(idx) ? existingDrops[idx] : nil)
                }

                if let idx = matchIdx {
                    let before = summary(items[idx])
                    let beforePrescriptions = items[idx].setPrescriptions
                    let targetSetCount = max(items[idx].suggestedSets ?? 0, setCount)
                    items[idx].suggestedSets = targetSetCount
                    items[idx].suggestedWeightKg = top.weightKg
                    items[idx].suggestedReps = top.reps
                    items[idx].setPrescriptions = mergedDropPrescriptions(observed: prescriptions,
                                                                          existing: existingDrops,
                                                                          targetCount: targetSetCount)
                    touchedItemIds.insert(items[idx].itemId)
                    let after = summary(items[idx])
                    if after != before || beforePrescriptions != items[idx].setPrescriptions {
                        diffs.append(ItemDiff(kind: .updated, exerciseName: ex.exerciseName,
                                              oldText: before, newText: after))
                    }
                } else {
                    let newItem = PlanItem(itemId: UUID(),
                                           unitKind: .dropSet,
                                           builtinExerciseCode: ex.builtinExerciseCode,
                                           customExerciseId: ex.customExerciseId,
                                           exerciseName: ex.exerciseName,
                                           primaryMuscle: ex.primaryMuscle,
                                           equipmentType: nil,
                                           orderIndex: nextOrder,
                                           suggestedSets: setCount,
                                           suggestedReps: top.reps,
                                           suggestedWeightKg: top.weightKg,
                                           setPrescriptions: prescriptions)
                    nextOrder += 1
                    items.append(newItem)
                    diffs.append(ItemDiff(kind: .added, exerciseName: ex.exerciseName,
                                          oldText: nil, newText: summary(newItem)))
                }
                continue
            }

            let completedRegular = completedRegularSets(from: ex)
            guard !completedRegular.isEmpty else { continue }
            let completedFormal = completedRegular.filter { !$0.isWarmupEffective }
            if matchIdx == nil && completedFormal.isEmpty { continue }
            let top = topStatEntry(in: completedFormal)
            let prescriptions = mergedRegularPrescriptions(observed: completedRegular,
                                                           existing: existingPrescriptions)
            let setCount = completedFormal.count

            if let idx = matchIdx {
                let before = summary(items[idx])
                let beforePrescriptions = items[idx].setPrescriptions
                if let top {
                    items[idx].suggestedSets = max(items[idx].suggestedSets ?? 0, setCount)
                    items[idx].suggestedWeightKg = top.weightKg
                    items[idx].suggestedReps = top.reps
                }
                items[idx].setPrescriptions = prescriptions
                touchedItemIds.insert(items[idx].itemId)
                let after = summary(items[idx])
                if after != before || beforePrescriptions != items[idx].setPrescriptions {
                    diffs.append(ItemDiff(kind: .updated, exerciseName: ex.exerciseName,
                                          oldText: before, newText: after))
                }
            } else {
                guard let top else { continue }
                let newItem = PlanItem(itemId: UUID(),
                                       builtinExerciseCode: ex.builtinExerciseCode,
                                       customExerciseId: ex.customExerciseId,
                                       exerciseName: ex.exerciseName,
                                       primaryMuscle: ex.primaryMuscle,
                                       equipmentType: nil,
                                       orderIndex: nextOrder,
                                       suggestedSets: setCount,
                                       suggestedReps: top.reps,
                                       suggestedWeightKg: top.weightKg,
                                       setPrescriptions: prescriptions)
                nextOrder += 1
                items.append(newItem)
                diffs.append(ItemDiff(kind: .added, exerciseName: ex.exerciseName,
                                      oldText: nil, newText: summary(newItem)))
            }
        }

        // kept：原计划里有、本次未被 UPDATE 命中的项（保留不动，仅作回执展示）。
        for original in planItems where !touchedItemIds.contains(original.itemId) {
            diffs.append(ItemDiff(kind: .kept, exerciseName: original.displayExerciseName,
                                  oldText: nil, newText: nil))
        }

        return Result(newItems: items, diffs: diffs)
    }

    private static func matchIndex(for ex: WorkoutExercise, in items: [PlanItem], isDropSetUnit: Bool) -> Int? {
        if let pid = ex.planItemId, let exact = items.firstIndex(where: { $0.itemId == pid && $0.isDropSet == isDropSetUnit && !$0.isSuperset }) {
            return exact
        }
        let fallbackMatches = items.indices.filter { !items[$0].isSuperset && items[$0].isDropSet == isDropSetUnit && items[$0].historyKey == ex.historyKey }
        return fallbackMatches.count == 1 ? fallbackMatches[0] : nil
    }

    private static func supersetMemberTarget(for ex: WorkoutExercise, in items: [PlanItem]) -> (itemIndex: Int, memberIndex: Int)? {
        guard let planItemId = ex.planItemId else { return nil }
        for itemIndex in items.indices where items[itemIndex].isSuperset {
            let members = items[itemIndex].orderedSupersetMembers
            if let memberIndex = members.firstIndex(where: { $0.memberId == planItemId }) {
                return (itemIndex, memberIndex)
            }
        }
        return nil
    }

    private static func completedRegularSets(from ex: WorkoutExercise) -> [WorkoutSet] {
        ex.sets
            .filter { $0.completed && !$0.isDropSet }
            .sorted {
                if $0.isWarmupEffective != $1.isWarmupEffective {
                    return $0.isWarmupEffective && !$1.isWarmupEffective
                }
                return $0.setIndex < $1.setIndex
            }
    }

    private static func topStatEntry(in sets: [WorkoutSet]) -> WorkoutSetStatEntry? {
        sets.flatMap(\.statEntries).max { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) }
    }

    private static func mergedRegularPrescriptions(observed: [WorkoutSet],
                                                   existing: [PlanSetPrescription]) -> [PlanSetPrescription] {
        let existingRegular = existing.filter { $0.setType != .drop }
        let existingWarmups = existingRegular.filter(\.isWarmupEffective)
        let existingFormal = existingRegular.filter { !$0.isWarmupEffective }
        let observedWarmups = observed.filter(\.isWarmupEffective)
        let observedFormal = observed.filter { !$0.isWarmupEffective }

        let warmups = observedWarmups.isEmpty
            ? existingWarmups
            : observedWarmups.enumerated().map { idx, set in
                prescription(from: set,
                             orderIndex: idx,
                             existing: existingWarmups.indices.contains(idx) ? existingWarmups[idx] : nil)
            }
        let formal = observedFormal.isEmpty
            ? existingFormal
            : observedFormal.enumerated().map { idx, set in
                prescription(from: set,
                             orderIndex: warmups.count + idx,
                             existing: existingFormal.indices.contains(idx) ? existingFormal[idx] : nil)
            }
        return PlanItem.reindexRegularPrescriptions(warmups + formal)
    }

    private static func prescription(from set: WorkoutSet, orderIndex: Int, existing: PlanSetPrescription? = nil) -> PlanSetPrescription {
        if set.isDropSet {
            let existingSegments = existing?.segments.sorted { $0.segmentIndex < $1.segmentIndex } ?? []
            let segments = set.effectiveSegments.enumerated().map { idx, segment in
                WorkoutSetSegment(segmentId: existingSegments.indices.contains(idx) ? existingSegments[idx].segmentId : segment.segmentId,
                                  segmentIndex: idx,
                                  weightKg: segment.weightKg,
                                  reps: segment.reps)
            }
            let summary = set.summaryWeightReps
            return PlanSetPrescription(prescriptionId: existing?.prescriptionId ?? UUID(),
                                       setType: .drop,
                                       orderIndex: orderIndex,
                                       weightKg: summary.weightKg,
                                       reps: summary.reps,
                                       isWarmup: false,
                                       segments: segments)
        }
        return PlanSetPrescription(prescriptionId: existing?.prescriptionId ?? UUID(),
                                   setType: set.setType,
                                   orderIndex: orderIndex,
                                   weightKg: set.weightKg,
                                   reps: set.reps,
                                   isWarmup: warmupPrescriptionValue(for: set, existing: existing))
    }

    private static func mergedDropPrescriptions(observed: [PlanSetPrescription],
                                                existing: [PlanSetPrescription],
                                                targetCount: Int) -> [PlanSetPrescription] {
        guard targetCount > 0 else { return [] }
        let fallback = observed.last ?? existing.last
        return (0..<targetCount).compactMap { index in
            if observed.indices.contains(index) {
                return reindexedDropPrescription(observed[index], orderIndex: index)
            }
            if existing.indices.contains(index) {
                return reindexedDropPrescription(existing[index], orderIndex: index)
            }
            guard let fallback else { return nil }
            return clonedDropPrescription(fallback, orderIndex: index)
        }
    }

    private static func reindexedDropPrescription(_ prescription: PlanSetPrescription,
                                                  orderIndex: Int) -> PlanSetPrescription {
        PlanSetPrescription(prescriptionId: prescription.prescriptionId,
                            setType: .drop,
                            orderIndex: orderIndex,
                            weightKg: prescription.weightKg,
                            reps: prescription.reps,
                            isWarmup: false,
                            segments: prescription.segments
                                .sorted { $0.segmentIndex < $1.segmentIndex }
                                .enumerated()
                                .map { idx, segment in
                                    WorkoutSetSegment(segmentId: segment.segmentId,
                                                      segmentIndex: idx,
                                                      weightKg: segment.weightKg,
                                                      reps: segment.reps)
                                })
    }

    private static func clonedDropPrescription(_ prescription: PlanSetPrescription,
                                               orderIndex: Int) -> PlanSetPrescription {
        PlanSetPrescription(setType: .drop,
                            orderIndex: orderIndex,
                            weightKg: prescription.weightKg,
                            reps: prescription.reps,
                            isWarmup: false,
                            segments: prescription.segments
                                .sorted { $0.segmentIndex < $1.segmentIndex }
                                .enumerated()
                                .map { idx, segment in
                                    WorkoutSetSegment(segmentIndex: idx,
                                                      weightKg: segment.weightKg,
                                                      reps: segment.reps)
                                })
    }

    private static func warmupPrescriptionValue(for set: WorkoutSet, existing: PlanSetPrescription?) -> Bool? {
        if set.isWarmupEffective { return true }
        return existing?.isWarmup == nil ? nil : false
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
