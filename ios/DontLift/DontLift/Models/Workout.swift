import Foundation
import SwiftData

/// 训练记录聚合根（对应后端 workout）。
/// 子节点 exercise/set 无独立同步信封，随聚合整体上传、服务端按 workoutId 全量替换（design.md D5）。
@Model
final class Workout: Syncable {
    @Attribute(.unique) var localId: UUID
    var serverId: UUID?
    var updatedAt: Date
    var deletedAt: Date?
    var version: Int
    var syncStatusRaw: String

    /// 来源计划模板（可空：徒手临时训练）。
    var planId: UUID?
    /// 来源 Team 分享计划（软关联，不参与计划同步）。
    var sourceShareId: UUID?
    var sourceShareVersionId: UUID?
    var sourcePlanNameSnapshot: String?
    var title: String?
    var startedAt: Date
    /// 计时起点（仅本地，不入同步信封）：nil = 计时未启动（会话已创建、浏览中）；
    /// 非 nil = 计时已启动（完成第一组或手动「开始训练」），REC 与训练时长均以此为基准。
    var timerStartedAt: Date?
    var endedAt: Date?
    var note: String?
    /// 一级训练单元索引 JSON。nil/空数组表示旧数据：按 `exercises.orderIndex` 派生为单动作单元。
    var unitsJSON: String?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var exercises: [WorkoutExercise]

    init(
        localId: UUID = UUID(),
        planId: UUID? = nil,
        sourceShareId: UUID? = nil,
        sourceShareVersionId: UUID? = nil,
        sourcePlanNameSnapshot: String? = nil,
        title: String? = nil,
        startedAt: Date = .now,
        timerStartedAt: Date? = nil,
        endedAt: Date? = nil,
        note: String? = nil,
        unitsJSON: String? = nil,
        exercises: [WorkoutExercise] = [],
        now: Date = .now
    ) {
        self.localId = localId
        self.serverId = nil
        self.updatedAt = now
        self.deletedAt = nil
        self.version = 0
        self.syncStatusRaw = SyncStatus.pendingCreate.rawValue
        self.planId = planId
        self.sourceShareId = sourceShareId
        self.sourceShareVersionId = sourceShareVersionId
        self.sourcePlanNameSnapshot = sourcePlanNameSnapshot
        self.title = title
        self.startedAt = startedAt
        self.timerStartedAt = timerStartedAt
        self.endedAt = endedAt
        self.note = note
        self.unitsJSON = unitsJSON
        self.exercises = exercises
    }
}

enum WorkoutUnitKind: String, Codable {
    case singleExercise
    case superset
}

/// 训练记录中的一级训练单元。真实重量/次数仍由 `WorkoutExercise/WorkoutSet` 承载；
/// 这里保存展示顺序、单动作/超级组边界和超级组轮后休息等结构信息。
struct WorkoutUnit: Codable, Identifiable, Hashable {
    var unitId: UUID
    var kindRaw: String
    var orderIndex: Int
    var singleExerciseId: UUID?
    var superset: WorkoutSupersetUnit?

    var id: UUID { unitId }

    init(
        unitId: UUID = UUID(),
        kind: WorkoutUnitKind,
        orderIndex: Int,
        singleExerciseId: UUID? = nil,
        superset: WorkoutSupersetUnit? = nil
    ) {
        self.unitId = unitId
        self.kindRaw = kind.rawValue
        self.orderIndex = orderIndex
        self.singleExerciseId = singleExerciseId
        self.superset = superset
    }

    var kind: WorkoutUnitKind {
        WorkoutUnitKind(rawValue: kindRaw) ?? .singleExercise
    }
}

struct WorkoutSupersetUnit: Codable, Hashable {
    var roundCount: Int
    var restAfterRoundSeconds: Int?
    var members: [WorkoutSupersetMember]

    init(roundCount: Int, restAfterRoundSeconds: Int? = nil, members: [WorkoutSupersetMember]) {
        self.roundCount = max(1, roundCount)
        self.restAfterRoundSeconds = restAfterRoundSeconds
        self.members = members.sorted { $0.orderIndex < $1.orderIndex }
    }
}

struct WorkoutSupersetMember: Codable, Identifiable, Hashable {
    var memberId: UUID
    var exerciseId: UUID
    var orderIndex: Int

    var id: UUID { memberId }

    init(memberId: UUID = UUID(), exerciseId: UUID, orderIndex: Int) {
        self.memberId = memberId
        self.exerciseId = exerciseId
        self.orderIndex = orderIndex
    }
}

// MARK: - 会话生命周期派生状态（不新增持久化字段，见 workout-session-lifecycle）

extension Workout {
    /// 进行中会话：未删除且未结束。全局至多一个（由 `WorkoutSession.beginSession` 守卫保证）。
    var isActive: Bool { deletedAt == nil && endedAt == nil }
    /// 已完成会话：未删除且已结束。
    var isFinished: Bool { deletedAt == nil && endedAt != nil }

    var storedUnits: [WorkoutUnit] {
        get { Self.decodeUnits(unitsJSON) }
        set { unitsJSON = Self.encodeUnits(newValue) }
    }

    /// 对外使用的一级训练单元列表。旧训练没有 `unitsJSON` 时自动按动作列表派生单动作单元。
    var trainingUnits: [WorkoutUnit] {
        let decoded = storedUnits
        guard !decoded.isEmpty else {
            return exercises
                .sorted { $0.orderIndex < $1.orderIndex }
                .enumerated()
                .map { index, ex in
                    WorkoutUnit(unitId: ex.localId,
                                kind: .singleExercise,
                                orderIndex: index,
                                singleExerciseId: ex.localId)
                }
        }

        let exerciseIds = Set(exercises.map(\.localId))
        let referencedIds = Set(decoded.flatMap { unit -> [UUID] in
            switch unit.kind {
            case .singleExercise:
                return unit.singleExerciseId.map { [$0] } ?? []
            case .superset:
                return unit.superset?.members.map(\.exerciseId) ?? []
            }
        })
        let validUnits = decoded.filter { unit in
            switch unit.kind {
            case .singleExercise:
                return unit.singleExerciseId.map { exerciseIds.contains($0) } ?? false
            case .superset:
                return unit.superset?.members.count == 2
                    && unit.superset?.members.allSatisfy({ exerciseIds.contains($0.exerciseId) }) == true
            }
        }
        let unreferenced = exercises
            .filter { !referencedIds.contains($0.localId) }
            .sorted { $0.orderIndex < $1.orderIndex }
            .enumerated()
            .map { offset, ex in
                WorkoutUnit(unitId: ex.localId,
                            kind: .singleExercise,
                            orderIndex: (validUnits.map(\.orderIndex).max() ?? -1) + offset + 1,
                            singleExerciseId: ex.localId)
            }
        return (validUnits + unreferenced).sorted { $0.orderIndex < $1.orderIndex }
    }

    var supersetExerciseIds: Set<UUID> {
        Set(trainingUnits.flatMap { unit -> [UUID] in
            guard unit.kind == .superset else { return [] }
            return unit.superset?.members.map(\.exerciseId) ?? []
        })
    }

    var totalExerciseCountForDisplay: Int {
        trainingUnits.reduce(0) { total, unit in
            switch unit.kind {
            case .singleExercise:
                return total + 1
            case .superset:
                return total + (unit.superset?.members.count ?? 0)
            }
        }
    }

    func exercise(id: UUID) -> WorkoutExercise? {
        exercises.first { $0.localId == id }
    }

    func updateTrainingUnits(_ units: [WorkoutUnit]) {
        storedUnits = normalizedUnits(units)
    }

    func appendSingleExerciseUnit(for exercise: WorkoutExercise) {
        var units = trainingUnits
        units.append(WorkoutUnit(kind: .singleExercise,
                                 orderIndex: (units.map(\.orderIndex).max() ?? -1) + 1,
                                 singleExerciseId: exercise.localId))
        updateTrainingUnits(units)
    }

    func appendSupersetUnit(first: WorkoutExercise,
                            second: WorkoutExercise,
                            roundCount: Int,
                            restAfterRoundSeconds: Int? = nil) {
        var units = trainingUnits
        let unit = WorkoutUnit(
            kind: .superset,
            orderIndex: (units.map(\.orderIndex).max() ?? -1) + 1,
            superset: WorkoutSupersetUnit(
                roundCount: roundCount,
                restAfterRoundSeconds: restAfterRoundSeconds,
                members: [
                    WorkoutSupersetMember(exerciseId: first.localId, orderIndex: 0),
                    WorkoutSupersetMember(exerciseId: second.localId, orderIndex: 1)
                ]
            )
        )
        units.append(unit)
        updateTrainingUnits(units)
    }

    func removeExerciseFromUnits(_ exerciseId: UUID) {
        let units = trainingUnits.compactMap { unit -> WorkoutUnit? in
            switch unit.kind {
            case .singleExercise:
                return unit.singleExerciseId == exerciseId ? nil : unit
            case .superset:
                guard unit.superset?.members.contains(where: { $0.exerciseId == exerciseId }) == false else { return nil }
                return unit
            }
        }
        updateTrainingUnits(units)
    }

    func replaceSupersetWithSingles(_ unitId: UUID) {
        var units = trainingUnits
        guard let idx = units.firstIndex(where: { $0.unitId == unitId }),
              let superset = units[idx].superset else { return }
        let baseOrder = units[idx].orderIndex
        let singles = superset.members.sorted { $0.orderIndex < $1.orderIndex }.enumerated().map { offset, member in
            WorkoutUnit(kind: .singleExercise,
                        orderIndex: baseOrder + offset,
                        singleExerciseId: member.exerciseId)
        }
        units.remove(at: idx)
        units.insert(contentsOf: singles, at: idx)
        updateTrainingUnits(units)
    }

    func updateSuperset(_ unit: WorkoutUnit) {
        var units = trainingUnits
        if let idx = units.firstIndex(where: { $0.unitId == unit.unitId }) {
            units[idx] = unit
            updateTrainingUnits(units)
        }
    }

    private func normalizedUnits(_ units: [WorkoutUnit]) -> [WorkoutUnit] {
        units
            .sorted { $0.orderIndex < $1.orderIndex }
            .enumerated()
            .map { index, unit in
                var copy = unit
                copy.orderIndex = index
                if var superset = copy.superset {
                    superset.members = superset.members.sorted { $0.orderIndex < $1.orderIndex }
                        .enumerated()
                        .map { memberIndex, member in
                            WorkoutSupersetMember(memberId: member.memberId,
                                                  exerciseId: member.exerciseId,
                                                  orderIndex: memberIndex)
                        }
                    superset.roundCount = max(1, superset.roundCount)
                    copy.superset = superset
                }
                return copy
            }
    }

    static func encodeUnits(_ units: [WorkoutUnit]) -> String? {
        guard !units.isEmpty,
              let data = try? JSONCoding.encoder.encode(units),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }

    static func decodeUnits(_ json: String?) -> [WorkoutUnit] {
        guard let json,
              !json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = json.data(using: .utf8),
              let units = try? JSONCoding.decoder.decode([WorkoutUnit].self, from: data) else {
            return []
        }
        return units.sorted { $0.orderIndex < $1.orderIndex }
    }
}

/// 训练中的一个动作条目（聚合子节点，不单独同步）。
@Model
final class WorkoutExercise {
    @Attribute(.unique) var localId: UUID
    var builtinExerciseCode: String?
    var customExerciseId: UUID?
    var exerciseName: String
    var primaryMuscle: String?
    var orderIndex: Int
    var note: String?
    /// 来源计划项 `PlanItem.itemId`（自适应回写的合并主键，design.md D3）。
    /// nil = 训练中临时新增、非来自计划的动作。SwiftData 轻量迁移：optional 默认 nil。
    var planItemId: UUID?

    var workout: Workout?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise)
    var sets: [WorkoutSet]

    init(
        localId: UUID = UUID(),
        builtinExerciseCode: String? = nil,
        customExerciseId: UUID? = nil,
        exerciseName: String,
        primaryMuscle: String? = nil,
        orderIndex: Int,
        note: String? = nil,
        planItemId: UUID? = nil,
        sets: [WorkoutSet] = []
    ) {
        self.localId = localId
        self.builtinExerciseCode = builtinExerciseCode
        self.customExerciseId = customExerciseId
        self.exerciseName = exerciseName
        self.primaryMuscle = primaryMuscle
        self.orderIndex = orderIndex
        self.note = note
        self.planItemId = planItemId
        self.sets = sets
    }
}

/// 组类型。`drop` 在 UI 中展示为「递减组」，内部只表示一个多段正式组，不校验重量方向。
/// 统计判据为 `!= .warmup`，新增「正式类」case 无需改统计代码。
enum WorkoutSetType: String, Codable, CaseIterable {
    case working   // 正式组
    case warmup    // 热身组
    case drop      // 递减组（多段正式组）
}

/// 递减组内的单段重量/次数。segment 不是独立同步实体，随父级 `WorkoutSet` 一起保存。
struct WorkoutSetSegment: Codable, Hashable, Identifiable {
    var segmentId: UUID
    var segmentIndex: Int
    var weightKg: Double?
    var reps: Int?

    var id: UUID { segmentId }

    init(segmentId: UUID = UUID(), segmentIndex: Int, weightKg: Double? = nil, reps: Int? = nil) {
        self.segmentId = segmentId
        self.segmentIndex = segmentIndex
        self.weightKg = weightKg
        self.reps = reps
    }
}

struct WorkoutSetStatEntry: Equatable, Hashable {
    var setId: UUID
    var segmentId: UUID?
    var weightKg: Double?
    var reps: Int?
}

/// 一个动作下的单组记录（聚合子节点，不单独同步）。新增组可由调用方按当前训练上下文预填重量/次数；
/// 未完成组不计入训练量/PR。
@Model
final class WorkoutSet {
    @Attribute(.unique) var localId: UUID
    var setIndex: Int
    var weightKg: Double?
    var reps: Int?
    var completed: Bool
    var note: String?
    /// 完成该组后启动休息时采用的预计秒数；nil 表示旧数据或尚未启动过休息。
    var plannedRestSeconds: Int?
    /// 该组休息完成后的真实秒数；nil 表示尚未产生休息回填。
    var actualRestSeconds: Int?
    /// 组类型 raw（默认 "working"）。SwiftData 轻量迁移：存储属性声明带默认值，旧本地记录读出即 working。
    var setTypeRaw: String = WorkoutSetType.working.rawValue
    /// 递减组分段。普通组/热身组保持空数组；SwiftData 轻量迁移时旧记录读出即空。
    var segments: [WorkoutSetSegment] = []

    var exercise: WorkoutExercise?

    init(
        localId: UUID = UUID(),
        setIndex: Int,
        weightKg: Double? = nil,
        reps: Int? = nil,
        completed: Bool = false,
        note: String? = nil,
        plannedRestSeconds: Int? = nil,
        actualRestSeconds: Int? = nil,
        setType: WorkoutSetType = .working,
        segments: [WorkoutSetSegment] = []
    ) {
        self.localId = localId
        self.setIndex = setIndex
        self.weightKg = weightKg
        self.reps = reps
        self.completed = completed
        self.note = note
        self.plannedRestSeconds = plannedRestSeconds
        self.actualRestSeconds = actualRestSeconds
        self.setTypeRaw = setType.rawValue
        self.segments = segments
        syncDropSummaryFromSegments()
    }
}

// 计算属性放 extension：避免 @Model 宏对类体内带 get/set 的计算属性注入访问器导致解析错。
extension WorkoutSet {
    /// 组类型枚举视图：get 未知值兜底 `.working`（跨版本安全），set 写回 raw。
    var setType: WorkoutSetType {
        get { WorkoutSetType(rawValue: setTypeRaw) ?? .working }
        set { setTypeRaw = newValue.rawValue }
    }

    /// 统计判据：正式组**且已完成**（`setType != .warmup && completed`）。
    /// 「非 warmup」使将来新增的正式类组类型自动计入；「completed」保证落值后未打勾的
    /// 预填残组不污染训练量/PR（design.md D2）。纯「热身/正式」展示判断应直接用 `setType`。
    var countsForStats: Bool { setType != .warmup && completed }

    var isDropSet: Bool { setType == .drop }

    var sortedSegments: [WorkoutSetSegment] {
        segments.sorted { $0.segmentIndex < $1.segmentIndex }
    }

    var effectiveSegments: [WorkoutSetSegment] {
        sortedSegments.filter { $0.weightKg != nil || $0.reps != nil }
    }

    var statEntries: [WorkoutSetStatEntry] {
        guard countsForStats else { return [] }
        if isDropSet {
            return effectiveSegments.map {
                WorkoutSetStatEntry(setId: localId, segmentId: $0.segmentId, weightKg: $0.weightKg, reps: $0.reps)
            }
        }
        return [WorkoutSetStatEntry(setId: localId, segmentId: nil, weightKg: weightKg, reps: reps)]
    }

    var topStatEntry: WorkoutSetStatEntry? {
        statEntries.max { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) }
    }

    var summaryWeightReps: (weightKg: Double?, reps: Int?) {
        if let top = topStatEntry { return (top.weightKg, top.reps) }
        if isDropSet, let first = effectiveSegments.first { return (first.weightKg, first.reps) }
        return (weightKg, reps)
    }

    var compactValueText: String {
        if isDropSet {
            let parts = effectiveSegments.map { segment in
                let w = segment.weightKg.map(formatKg) ?? "—"
                let r = segment.reps.map(String.init) ?? "—"
                return "\(w)×\(r)"
            }
            if parts.isEmpty { return "递减组" }
            if parts.count <= 2 { return parts.joined(separator: " / ") }
            return "\(parts[0]) +\(parts.count - 1)组"
        }
        let w = weightKg.map(formatKg) ?? "—"
        let r = reps.map(String.init) ?? "—"
        return "\(w)×\(r)"
    }

    func syncDropSummaryFromSegments() {
        guard isDropSet else { return }
        let valid = effectiveSegments
        if let top = valid.max(by: { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) }) {
            weightKg = top.weightKg
            reps = top.reps
        } else {
            weightKg = nil
            reps = nil
        }
    }

    func configureAsDropSet(defaultWeight: Double?, defaultReps: Int?) {
        setType = .drop
        let first = WorkoutSetSegment(segmentIndex: 0, weightKg: defaultWeight, reps: defaultReps)
        let second = WorkoutSetSegment(segmentIndex: 1)
        segments = [first, second]
        syncDropSummaryFromSegments()
    }

    func convertDropToWorkingUsingFirstSegment() {
        let first = effectiveSegments.first
        setType = .working
        weightKg = first?.weightKg ?? weightKg
        reps = first?.reps ?? reps
        segments = []
    }

    func appendDropSegment(prefillFromLast: Bool = true) -> WorkoutSetSegment {
        let next = (segments.map(\.segmentIndex).max() ?? -1) + 1
        let previous = prefillFromLast ? effectiveSegments.last : nil
        let segment = WorkoutSetSegment(segmentIndex: next,
                                        weightKg: previous?.weightKg,
                                        reps: previous?.reps)
        segments.append(segment)
        syncDropSummaryFromSegments()
        return segment
    }

    func removeDropSegment(_ segmentId: UUID) {
        segments.removeAll { $0.segmentId == segmentId }
        for idx in segments.indices { segments[idx].segmentIndex = idx }
        syncDropSummaryFromSegments()
    }

    func pruneEmptyDropSegments(keepAtLeastOne: Bool) {
        guard isDropSet else { return }
        segments.removeAll { $0.weightKg == nil && $0.reps == nil }
        if keepAtLeastOne && segments.isEmpty {
            segments = [WorkoutSetSegment(segmentIndex: 0)]
        }
        for idx in segments.indices { segments[idx].segmentIndex = idx }
        syncDropSummaryFromSegments()
    }
}

extension WorkoutExercise {
    /// 展示用排序：热身组吸顶（warmup 段在前），段内按 setIndex 稳定升序（design.md D4）。
    var displaySortedSets: [WorkoutSet] {
        sets.sorted {
            let lw = $0.setType == .warmup, rw = $1.setType == .warmup
            if lw != rw { return lw }      // warmup 段在前
            return $0.setIndex < $1.setIndex
        }
    }

    /// 上一**正式**组重量（按 setIndex 取最后一个正式组），用于「加一组」预填源（热身组不作预填）。
    var lastWorkingWeight: Double? {
        sets.filter { $0.setType != .warmup }.sorted { $0.setIndex < $1.setIndex }.last?.summaryWeightReps.weightKg
    }

    /// 上一**正式**组的重量与次数，用于新增正式组时继承输入值（热身组不作预填源）。
    var lastWorkingSetValues: (weightKg: Double?, reps: Int?) {
        guard let last = sets.filter({ $0.setType != .warmup }).sorted(by: { $0.setIndex < $1.setIndex }).last else {
            return (nil, nil)
        }
        return last.summaryWeightReps
    }

    /// 切换某组 working ⇄ warmup，并重排到对应段尾（赋最大 setIndex+1）。仅改模型，保存由调用方负责。
    func toggleSetType(_ set: WorkoutSet) {
        set.setType = (set.setType == .warmup) ? .working : .warmup
        set.setIndex = (sets.map(\.setIndex).max() ?? -1) + 1
    }
}
