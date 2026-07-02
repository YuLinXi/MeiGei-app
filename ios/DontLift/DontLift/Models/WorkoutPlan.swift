import Foundation
import SwiftData

/// 训练计划模式。`strict`=照剧本执行（开始训练整组复制预设、完成不回写）；
/// `adaptive`=活文档（首次用预设落值、完成后实绩 upsert 回写计划）。
/// 可扩展枚举：未识别值兜底 `.adaptive`（跨版本安全）。
enum WorkoutPlanMode: String, Codable, CaseIterable {
    case strict     // 严格模式
    case adaptive   // 自适应模式（默认）
}

extension WorkoutPlanMode {
    var displayName: String {
        switch self {
        case .strict: "严格"
        case .adaptive: "自适应"
        }
    }

    var title: String { "\(displayName)模式" }

    var detailText: String {
        switch self {
        case .adaptive:
            "自适应模式：完成训练后，实绩会自动更新此计划；组数只增不减，重量/次数按实绩更新，训练中新增的动作并入计划。"
        case .strict:
            "严格模式：开始训练时整组复制预设（组数/次数/重量），完成后不回写。需为每个动作填写组数与次数。"
        }
    }
}

enum PlanDefaults {
    static let suggestedSets = 4
    static let suggestedReps = 10
}

/// 训练计划中的单组处方。普通组直接使用 `weightKg/reps`；递减组使用 `segments` 作为真相。
struct PlanSetPrescription: Codable, Identifiable, Hashable {
    var prescriptionId: UUID
    var setTypeRaw: String
    var orderIndex: Int
    var weightKg: Double?
    var reps: Int?
    var segments: [WorkoutSetSegment]

    var id: UUID { prescriptionId }

    init(
        prescriptionId: UUID = UUID(),
        setType: WorkoutSetType = .working,
        orderIndex: Int,
        weightKg: Double? = nil,
        reps: Int? = nil,
        segments: [WorkoutSetSegment] = []
    ) {
        self.prescriptionId = prescriptionId
        self.setTypeRaw = setType.rawValue
        self.orderIndex = orderIndex
        self.weightKg = weightKg
        self.reps = reps
        self.segments = segments
    }

    var setType: WorkoutSetType {
        get { WorkoutSetType(rawValue: setTypeRaw) ?? .working }
        set { setTypeRaw = newValue.rawValue }
    }
}

/// 训练计划模板里的单个动作项。每项带稳定 `itemId`（design.md D5），
/// 供编辑、Fork、diff 时定位。整体以 jsonb 文档随计划读写。
struct PlanItem: Codable, Identifiable, Hashable {
    var itemId: UUID
    /// 内置动作 code 或自定义动作引用，二选一。
    var builtinExerciseCode: String?
    var customExerciseId: UUID?
    var exerciseName: String
    var primaryMuscle: String?
    var equipmentType: String?
    var orderIndex: Int
    var suggestedSets: Int?
    var suggestedReps: Int?
    var suggestedWeightKg: Double?
    /// 可选逐组处方；缺失时继续使用 `suggested*` 兼容旧计划。
    var setPrescriptions: [PlanSetPrescription]?

    var id: UUID { itemId }

    init(
        itemId: UUID = UUID(),
        builtinExerciseCode: String? = nil,
        customExerciseId: UUID? = nil,
        exerciseName: String,
        primaryMuscle: String? = nil,
        equipmentType: String? = nil,
        orderIndex: Int,
        suggestedSets: Int? = nil,
        suggestedReps: Int? = nil,
        suggestedWeightKg: Double? = nil,
        setPrescriptions: [PlanSetPrescription]? = nil
    ) {
        self.itemId = itemId
        self.builtinExerciseCode = builtinExerciseCode
        self.customExerciseId = customExerciseId
        self.exerciseName = exerciseName
        self.primaryMuscle = primaryMuscle
        self.equipmentType = equipmentType
        self.orderIndex = orderIndex
        self.suggestedSets = suggestedSets
        self.suggestedReps = suggestedReps
        self.suggestedWeightKg = suggestedWeightKg
        self.setPrescriptions = setPrescriptions
    }
}

extension PlanItem {
    private var trimmedSnapshotName: String? {
        let value = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var resolvedBuiltin: BuiltinExercise? {
        ExerciseLibrary.resolve(code: builtinExerciseCode, name: trimmedSnapshotName)
    }

    /// 展示/开始训练优先使用本地动作库名称；本地未知时使用计划项随包保存的名称快照。
    var resolvedExerciseName: String? {
        resolvedBuiltin?.name ?? trimmedSnapshotName
    }

    var displayExerciseName: String {
        resolvedExerciseName ?? "未知动作"
    }

    var resolvedPrimaryMuscle: String? {
        primaryMuscle ?? resolvedBuiltin?.category
    }

    var resolvedEquipmentType: String? {
        equipmentType ?? resolvedBuiltin?.equipmentType
    }

    static func unstartableItems(in items: [PlanItem]) -> [PlanItem] {
        items.filter { $0.resolvedExerciseName == nil }
    }

    static func unstartableMessage(for items: [PlanItem]) -> String {
        let refs = items.map { item in
            item.builtinExerciseCode ?? item.customExerciseId?.uuidString ?? item.itemId.uuidString
        }
        return "计划包含无法识别且缺少名称快照的动作：" + refs.joined(separator: "、") + "。请更新 App 或重新编辑该计划后再开始训练。"
    }

    var orderedSetPrescriptions: [PlanSetPrescription] {
        (setPrescriptions ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    func manualSetPrescriptionsForEditing() -> [PlanSetPrescription] {
        let existing = orderedSetPrescriptions
        if !existing.isEmpty { return Self.normalizedManualSetPrescriptions(existing) }
        let count = max(1, suggestedSets ?? PlanDefaults.suggestedSets)
        return (0..<count).map {
            PlanSetPrescription(orderIndex: $0,
                                weightKg: suggestedWeightKg,
                                reps: suggestedReps ?? PlanDefaults.suggestedReps)
        }
    }

    mutating func applyManualSetPrescriptions(_ prescriptions: [PlanSetPrescription]) {
        let normalized = Self.normalizedManualSetPrescriptions(prescriptions)
        let finalPrescriptions = normalized.isEmpty
            ? [PlanSetPrescription(orderIndex: 0, reps: PlanDefaults.suggestedReps)]
            : normalized
        setPrescriptions = finalPrescriptions
        suggestedSets = finalPrescriptions.count
        let summary = Self.summaryWeightReps(from: finalPrescriptions)
        suggestedWeightKg = summary.weightKg
        suggestedReps = summary.reps
    }

    static func normalizedManualSetPrescriptions(_ prescriptions: [PlanSetPrescription]) -> [PlanSetPrescription] {
        prescriptions.enumerated().map { idx, prescription in
            if prescription.setType == .drop {
                let sourceSegments = prescription.segments.isEmpty
                    ? [WorkoutSetSegment(segmentIndex: 0, weightKg: prescription.weightKg, reps: prescription.reps),
                       WorkoutSetSegment(segmentIndex: 1)]
                    : prescription.segments
                let segments = sourceSegments
                    .sorted { $0.segmentIndex < $1.segmentIndex }
                    .enumerated()
                    .map { segmentIndex, segment in
                        WorkoutSetSegment(segmentId: segment.segmentId,
                                          segmentIndex: segmentIndex,
                                          weightKg: segment.weightKg,
                                          reps: segment.reps)
                    }
                let summary = summaryWeightReps(from: segments)
                return PlanSetPrescription(prescriptionId: prescription.prescriptionId,
                                           setType: .drop,
                                           orderIndex: idx,
                                           weightKg: summary.weightKg,
                                           reps: summary.reps,
                                           segments: segments)
            }
            return PlanSetPrescription(prescriptionId: prescription.prescriptionId,
                                       setType: .working,
                                       orderIndex: idx,
                                       weightKg: prescription.weightKg,
                                       reps: prescription.reps)
        }
    }

    private static func summaryWeightReps(from prescriptions: [PlanSetPrescription]) -> (weightKg: Double?, reps: Int?) {
        let entries = prescriptions.flatMap { prescription -> [(weightKg: Double?, reps: Int?)] in
            if prescription.setType == .drop {
                return prescription.segments
                    .sorted { $0.segmentIndex < $1.segmentIndex }
                    .map { ($0.weightKg, $0.reps) }
            }
            return [(prescription.weightKg, prescription.reps)]
        }
        return summaryWeightReps(from: entries)
    }

    private static func summaryWeightReps(from segments: [WorkoutSetSegment]) -> (weightKg: Double?, reps: Int?) {
        summaryWeightReps(from: segments
            .sorted { $0.segmentIndex < $1.segmentIndex }
            .map { ($0.weightKg, $0.reps) })
    }

    private static func summaryWeightReps(from entries: [(weightKg: Double?, reps: Int?)]) -> (weightKg: Double?, reps: Int?) {
        let effective = entries.filter { $0.weightKg != nil || $0.reps != nil }
        if let top = effective.filter({ $0.weightKg != nil }).max(by: { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) }) {
            return (top.weightKg, top.reps)
        }
        if let first = effective.first { return (first.weightKg, first.reps) }
        return (nil, nil)
    }
}

/// 训练计划模板（参与同步，对应后端 workout_plan，items 以 jsonb 整体存储）。
@Model
final class WorkoutPlan: Syncable {
    @Attribute(.unique) var localId: UUID
    var serverId: UUID?
    var updatedAt: Date
    var deletedAt: Date?
    var version: Int
    var syncStatusRaw: String

    var name: String
    var items: [PlanItem]
    /// 计划模式 raw（默认 "adaptive"）。SwiftData 轻量迁移：存储属性带默认值，旧本地记录读出即 adaptive。
    var modeRaw: String = WorkoutPlanMode.adaptive.rawValue
    /// Fork 来源软指针；原模板增删不影响副本。
    var forkedFrom: UUID?
    /// 来源 Team 分享版本；再次 fork 新版本时生成新的独立计划，不做后续同步。
    var forkedFromShareVersionId: UUID?
    /// 发布到的 Team；nil 表示私有。
    var sharedToTeamId: UUID?
    /// 所属计划分组；nil 表示未分组。
    var groupId: UUID?
    /// 组内排序值，升序排列；同值时列表按 updatedAt 兜底。
    var sortOrder: Int = 0

    init(
        localId: UUID = UUID(),
        name: String,
        items: [PlanItem] = [],
        mode: WorkoutPlanMode = .adaptive,
        forkedFrom: UUID? = nil,
        forkedFromShareVersionId: UUID? = nil,
        sharedToTeamId: UUID? = nil,
        groupId: UUID? = nil,
        sortOrder: Int = 0,
        now: Date = .now
    ) {
        self.localId = localId
        self.serverId = nil
        self.updatedAt = now
        self.deletedAt = nil
        self.version = 0
        self.syncStatusRaw = SyncStatus.pendingCreate.rawValue
        self.name = name
        self.items = items
        self.modeRaw = mode.rawValue
        self.forkedFrom = forkedFrom
        self.forkedFromShareVersionId = forkedFromShareVersionId
        self.sharedToTeamId = sharedToTeamId
        self.groupId = groupId
        self.sortOrder = sortOrder
    }
}

extension WorkoutPlan {
    /// 计划模式枚举视图：get 未知值兜底 `.adaptive`（跨版本安全），set 写回 raw。
    var mode: WorkoutPlanMode {
        get { WorkoutPlanMode(rawValue: modeRaw) ?? .adaptive }
        set { modeRaw = newValue.rawValue }
    }

    /// 模板内建议组数之和（各动作项 `suggestedSets` 累加，nil 视为 0）。
    /// 计划详情 statRow 与计划列表 featured 卡共用，避免两处算法漂移。
    var totalSuggestedSets: Int {
        items.reduce(0) { total, item in
            total + (item.setPrescriptions?.count ?? item.suggestedSets ?? 0)
        }
    }

    /// 「进行中」计划判定——首页开始 CTA 与「计划」页共用同一份逻辑，避免两处漂移。
    /// 优先取近 14 天内有关联已完成训练的计划；否则退回最近更新的一个；无计划为 nil。
    /// - Parameters:
    ///   - plans: 有效计划集（调用方按 `updatedAt` 倒序传入）。
    ///   - workouts: 训练集，用于判定近 14 天关联。
    static func active(in plans: [WorkoutPlan], workouts: [Workout], now: Date = .now) -> WorkoutPlan? {
        let cutoff = now.addingTimeInterval(-14 * 86_400)
        let recentPlanIds = Set(workouts
            .filter { $0.endedAt != nil && $0.startedAt > cutoff && $0.planId != nil }
            .compactMap { $0.planId })
        return plans.first(where: { recentPlanIds.contains($0.localId) }) ?? plans.first
    }
}
