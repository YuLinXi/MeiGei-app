import Foundation
import SwiftData
import CryptoKit

/// 候选解锁成就（未持久化内存模型）
struct BadgeGrantCandidate: Equatable, Hashable, Sendable {
    let badgeCode: String
    let unlockedAt: Date
    let workoutId: UUID?
    let snapshotMetric: Double
}

/// 徽章当前达成进度（供徽章馆与个人中心展示）
struct BadgeProgress: Equatable, Sendable {
    let definition: BadgeDefinition
    let isUnlocked: Bool
    let currentMetric: Double
    let targetMetric: Double
    let grant: BadgeGrantCandidate?
    let progressRatio: Double
    let progressText: String
}

struct BadgeSegmentSnapshot: Sendable {
    let weightKg: Double?
    let reps: Int?
}

struct BadgeSetSnapshot: Sendable {
    let weightKg: Double?
    let reps: Int?
    let completed: Bool
    let isWarmup: Bool
    let segments: [BadgeSegmentSnapshot]
    var isDropSet: Bool = false
}

struct BadgeExerciseSnapshot: Sendable {
    let historyKey: String
    let liftCode: String?
    let planItemId: UUID?
    let sets: [BadgeSetSnapshot]

    nonisolated var isAssistedWeight: Bool { ExerciseWeightSemantics.isAssisted(historyKey) }
    nonisolated var assistancePerformances: [ExerciseWeightSemantics.Performance] {
        sets.filter { $0.completed && !$0.isWarmup }.flatMap { set in
            let entries = set.isDropSet ? set.segments : [BadgeSegmentSnapshot(weightKg: set.weightKg, reps: set.reps)]
            return entries.compactMap { entry -> ExerciseWeightSemantics.Performance? in
                guard let weight = entry.weightKg, let reps = entry.reps else { return nil }
                let value = ExerciseWeightSemantics.Performance(weight: weight, reps: reps)
                return value.isValid ? value : nil
            }
        }
    }

    nonisolated var completedSetCount: Int { sets.filter { $0.completed && !$0.isWarmup }.count }

    nonisolated var maxWorkingWeight: Double? {
        sets.flatMap { set -> [Double] in
            guard set.completed && !set.isWarmup else { return [] }
            if set.isDropSet {
                return set.segments.compactMap { segment in
                    guard (segment.reps ?? 0) > 0, let weight = segment.weightKg, weight > 0 else { return nil }
                    return weight
                }
            }
            guard (set.reps ?? 0) > 0, let weight = set.weightKg, weight > 0 else { return [] }
            return [weight]
        }.max()
    }

    nonisolated var volumeKg: Double {
        guard !isAssistedWeight else { return 0 }
        return sets.reduce(0) { total, set in
            guard set.completed && !set.isWarmup else { return total }
            if set.isDropSet {
                return total + set.segments.reduce(0) { $0 + ($1.weightKg ?? 0) * Double($1.reps ?? 0) }
            }
            return total + (set.weightKg ?? 0) * Double(set.reps ?? 0)
        }
    }
}

struct BadgeWorkoutSnapshot: Sendable {
    let id: UUID
    let planId: UUID?
    let startedAt: Date
    let endedAt: Date
    let updatedAt: Date
    let bodyWeightKgAtCompletion: Double?
    let exercises: [BadgeExerciseSnapshot]

    nonisolated var volumeKg: Double { exercises.reduce(0) { $0 + $1.volumeKg } }
    nonisolated var completedSetCount: Int { exercises.reduce(0) { $0 + $1.completedSetCount } }
    nonisolated var allSetsCompleted: Bool {
        !exercises.isEmpty && exercises.allSatisfy { !$0.sets.isEmpty && $0.sets.allSatisfy(\.completed) }
    }
}

private struct BadgePlanSnapshot: Sendable {
    let id: UUID
    let requirements: [BadgePlanRequirement]

    nonisolated var requiredSetsByItemId: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: requirements.map { ($0.itemId, $0.requiredSetCount) })
    }
}

private struct BadgePlanRequirement: Sendable {
    let itemId: UUID
    let requiredSetCount: Int
}

private struct BadgeBackfillInput: Sendable {
    let workouts: [BadgeWorkoutSnapshot]
    let plans: [BadgePlanSnapshot]
    let existingGrantCodes: [String]
}

/// 国际力量举（IPF）标准三大项枚举
enum Big3Lift: String, CaseIterable {
    case bench
    case squat
    case deadlift

    var displayName: String {
        switch self {
        case .bench: return "杠铃卧推"
        case .squat: return "杠铃深蹲"
        case .deadlift: return "杠铃硬拉"
        }
    }

    /// 严格识别动作是否属于 IPF 国际力量举标准三大项：
    /// - 深蹲：`BB_SQUAT`
    /// - 卧推：`BB_BENCH_PRESS`
    /// - 硬拉：`DEADLIFT` 或 `SUMO_DEADLIFT`
    /// 任何史密斯、哑铃、器械或自定义动作均严格排除返回 nil。
    static func identify(exercise: WorkoutExercise) -> Big3Lift? {
        guard exercise.customExerciseId == nil else { return nil }
        let code = exercise.resolvedBuiltinExercise?.code ?? exercise.builtinExerciseCode
        switch code {
        case "BB_BENCH_PRESS":
            return .bench
        case "BB_SQUAT":
            return .squat
        case "DEADLIFT", "SUMO_DEADLIFT":
            return .deadlift
        default:
            return nil
        }
    }
}

/// 严肃力量训练成就徽章评估与回溯引擎
enum BadgeEngine {
    /// UserDefaults 标记：存量历史训练回溯是否已完成
    static let backfillCompletedKey = "hasCompletedBadgeBackfill"
    static let backfillFingerprintKey = "hasCompletedBadgeBackfill_fingerprint_v2"
    /// UserDefaults 标记：生涯成就回顾弹窗是否已对用户展示过
    static let careerReviewShownKey = "hasShownCareerBadgeReview"

    // MARK: - 三大项与力量指标计算

    /// 提取单个动作中有效完成的正式组最高重量（排除热身组、0 次及未完成组）
    static func maxWorkingWeight(in exercise: WorkoutExercise) -> Double? {
        exercise.sets
            .filter(\.countsForStats)
            .flatMap(\.statEntries)
            .compactMap { entry -> Double? in
                guard let w = entry.weightKg, let r = entry.reps, r > 0, w > 0 else { return nil }
                return w
            }
            .max()
    }

    /// 提取单次训练中某特定三大项动作的最高重量
    static func maxWeight(in workout: Workout, for lift: Big3Lift) -> Double? {
        workout.exercises
            .filter { Big3Lift.identify(exercise: $0) == lift }
            .compactMap { maxWorkingWeight(in: $0) }
            .max()
    }

    /// 计算一组训练中三大项各自的历史最高 PR 重量（硬拉在常规与相扑中取更高值）
    static func big3PRs(in workouts: [Workout]) -> (bench: Double?, squat: Double?, deadlift: Double?) {
        var maxBench: Double?
        var maxSquat: Double?
        var maxDeadlift: Double?

        for w in workouts where w.deletedAt == nil && w.endedAt != nil {
            if let b = maxWeight(in: w, for: .bench) {
                maxBench = max(maxBench ?? b, b)
            }
            if let s = maxWeight(in: w, for: .squat) {
                maxSquat = max(maxSquat ?? s, s)
            }
            if let d = maxWeight(in: w, for: .deadlift) {
                maxDeadlift = max(maxDeadlift ?? d, d)
            }
        }
        return (maxBench, maxSquat, maxDeadlift)
    }

    /// 计算三大项历史 PR 总和（只有三项均至少有一次有效成绩时，总和方才成立）
    static func big3Total(in workouts: [Workout]) -> Double? {
        let prs = big3PRs(in: workouts)
        guard let b = prs.bench, let s = prs.squat, let d = prs.deadlift else {
            return nil
        }
        return b + s + d
    }

    /// 计算累计总吨位（排除软删和未完成）
    static func cumulativeTonnage(in workouts: [Workout]) -> Double {
        workouts
            .filter { $0.deletedAt == nil && $0.endedAt != nil }
            .reduce(0.0) { $0 + $1.completedStatVolumeKg }
    }

    /// 计算有效训练总次数
    static func completedWorkoutCount(in workouts: [Workout]) -> Int {
        workouts.filter { $0.deletedAt == nil && $0.endedAt != nil }.count
    }

    // MARK: - 单次战役极限判定辅助

    /// 检测单次训练中打破历史 PR 的动作项数（排除首次尝试，必须先有历史记录且本次超过历史纪录）
    static func detectBrokenPRCount(in workout: Workout, priorWorkouts: [Workout]) -> Int {
        var priorBestByKey: [String: Double] = [:]
        for w in priorWorkouts where w.deletedAt == nil && w.endedAt != nil && w.localId != workout.localId {
            for ex in w.exercises {
                let key = ex.historyKey
                if let maxW = ex.sets.filter(\.countsForStats).flatMap(\.statEntries).compactMap(\.weightKg).max() {
                    priorBestByKey[key] = max(priorBestByKey[key] ?? maxW, maxW)
                }
            }
        }

        var brokenCount = 0
        var seenKeys = Set<String>()

        for ex in workout.exercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            let key = ex.historyKey
            guard !seenKeys.contains(key) else { continue }
            if ex.isAssistedWeight {
                let prior = priorWorkouts.filter { $0.isFinished && $0.localId != workout.localId && $0.startedAt < workout.startedAt }
                    .flatMap(\.exercises).filter(\.isAssistedWeight).flatMap(\.assistancePerformances)
                if ex.assistancePerformances.contains(where: { ExerciseWeightSemantics.isAssistanceBreakthrough($0, prior: prior) }) {
                    brokenCount += 1
                    seenKeys.insert(key)
                }
                continue
            }
            guard let sessionMax = ex.sets.filter(\.countsForStats).flatMap(\.statEntries).compactMap(\.weightKg).max(), sessionMax > 0 else {
                continue
            }
            if let prior = priorBestByKey[key], prior > 0, sessionMax > prior {
                brokenCount += 1
                seenKeys.insert(key)
            }
        }
        return brokenCount
    }

    /// 判定是否 100% 严格执行计划（针对来自计划的训练）
    static func isPerfectPlanExecution(workout: Workout, plan: WorkoutPlan?) -> Bool {
        guard workout.planId != nil else { return false }
        guard !workout.exercises.isEmpty else { return false }

        // 所有动作的组必须全部已完成（无未完成组且非空）
        let allSetsCompleted = workout.exercises.allSatisfy { ex in
            !ex.sets.isEmpty && ex.sets.allSatisfy(\.completed)
        }
        guard allSetsCompleted else { return false }

        guard let plan, !plan.items.isEmpty else { return false }

        // 严格对比计划项：计划内的每一项动作与组数均需全达成
        for item in plan.items {
            switch item.unitKind {
            case .singleExercise, .dropSet:
                guard let ex = workout.exercises.first(where: { $0.planItemId == item.itemId }) else {
                    return false
                }
                let requiredSets = item.suggestedSets ?? item.setPrescriptions?.count ?? 1
                let completedCount = ex.sets.filter(\.completed).count
                if completedCount < requiredSets { return false }
            case .superset:
                let members = item.orderedSupersetMembers
                for member in members {
                    guard let ex = workout.exercises.first(where: { $0.planItemId == member.memberId }) else {
                        return false
                    }
                    let requiredRounds = item.supersetRounds
                    let completedCount = ex.sets.filter(\.completed).count
                    if completedCount < requiredRounds { return false }
                }
            }
        }

        return true
    }

    static func snapshot(_ workout: Workout) -> BadgeWorkoutSnapshot? {
        guard workout.deletedAt == nil, let endedAt = workout.endedAt else { return nil }
        return BadgeWorkoutSnapshot(
            id: workout.localId,
            planId: workout.planId,
            startedAt: workout.startedAt,
            endedAt: endedAt,
            updatedAt: workout.updatedAt,
            bodyWeightKgAtCompletion: workout.bodyWeightKgAtCompletion,
            exercises: workout.exercises.sorted { $0.orderIndex < $1.orderIndex }.map { exercise in
                let liftCode: String?
                switch Big3Lift.identify(exercise: exercise) {
                case .bench: liftCode = Big3Lift.bench.rawValue
                case .squat: liftCode = Big3Lift.squat.rawValue
                case .deadlift: liftCode = Big3Lift.deadlift.rawValue
                case nil: liftCode = nil
                }
                return BadgeExerciseSnapshot(
                    historyKey: exercise.historyKey,
                    liftCode: liftCode,
                    planItemId: exercise.planItemId,
                    sets: exercise.sets.sorted { $0.setIndex < $1.setIndex }.map {
                        BadgeSetSnapshot(
                            weightKg: $0.weightKg,
                            reps: $0.reps,
                            completed: $0.completed,
                            isWarmup: $0.isWarmupEffective,
                            segments: ($0.isDropSet ? $0.sortedSegments : []).map {
                                BadgeSegmentSnapshot(weightKg: $0.weightKg, reps: $0.reps)
                            },
                            isDropSet: $0.isDropSet
                        )
                    }
                )
            }
        )
    }

    private static func snapshot(_ plan: WorkoutPlan) -> BadgePlanSnapshot {
        var requirements: [UUID: Int] = [:]
        for item in plan.items {
            if item.isSuperset {
                for member in item.orderedSupersetMembers {
                    requirements[member.memberId] = item.supersetRounds
                }
            } else {
                requirements[item.itemId] = item.suggestedSets ?? item.setPrescriptions?.count ?? 1
            }
        }
        return BadgePlanSnapshot(
            id: plan.localId,
            requirements: requirements
                .map { BadgePlanRequirement(itemId: $0.key, requiredSetCount: $0.value) }
                .sorted { $0.itemId.uuidString < $1.itemId.uuidString }
        )
    }

    // MARK: - 纯函数式徽章评估（增量单次训练结算）

    /// 评估单次训练结算触发的新徽章
    /// - Parameters:
    ///   - workout: 刚刚完成的训练（已置位 `endedAt != nil`）
    ///   - allFinishedWorkouts: 包含本次在内的全部历史有效完成训练
    ///   - currentGrants: 当前已获得的徽章 code 集合
    ///   - currentWeight: 保留的调用参数；自重倍数判定只使用训练完成时保存的体重快照
    ///   - plan: 本次训练对应的计划对象（可选）
    /// - Returns: 本次新达成的徽章候选列表
    static func evaluateIncremental(
        workout: Workout,
        allFinishedWorkouts: [Workout],
        currentGrants: Set<String>,
        currentWeight _: Double?,
        plan: WorkoutPlan? = nil
    ) -> [BadgeGrantCandidate] {
        guard let value = snapshot(workout) else { return [] }
        return evaluateIncremental(workout: value, allFinishedWorkouts: allFinishedWorkouts.compactMap { snapshot($0) },
                                   currentGrants: currentGrants,
                                   perfectPlanExecution: isPerfectPlanExecution(workout: workout, plan: plan))
    }

    nonisolated static func evaluateIncremental(
        workout: BadgeWorkoutSnapshot,
        allFinishedWorkouts: [BadgeWorkoutSnapshot],
        currentGrants: Set<String>,
        perfectPlanExecution: Bool
    ) -> [BadgeGrantCandidate] {
        var newCandidates: [BadgeGrantCandidate] = []
        let unlockedAt = workout.endedAt
        let workoutId = workout.id

        func recordIfUnlocked(code: String, metric: Double) {
            guard !currentGrants.contains(code) && !newCandidates.contains(where: { $0.badgeCode == code }) else { return }
            newCandidates.append(BadgeGrantCandidate(
                badgeCode: code,
                unlockedAt: unlockedAt,
                workoutId: workoutId,
                snapshotMetric: metric
            ))
        }

        // 1. 力量与三大项俱乐部（9 枚）
        // 自重倍数必须绑定触发该徽章的训练；历史 PR 不能在之后借用新的当前体重补授。
        let workoutPRs = snapshotBig3PRs(in: [workout])
        if let bw = workout.bodyWeightKgAtCompletion, bw > 0 {
            if let bench = workoutPRs.bench {
                let multiplier = (bench / bw * 100).rounded() / 100
                if bench >= 1.0 * bw { recordIfUnlocked(code: "strength_bw_bench_1_0", metric: multiplier) }
                if bench >= 1.5 * bw { recordIfUnlocked(code: "strength_bw_bench_1_5", metric: multiplier) }
            }
            if let squat = workoutPRs.squat {
                let multiplier = (squat / bw * 100).rounded() / 100
                if squat >= 1.5 * bw { recordIfUnlocked(code: "strength_bw_squat_1_5", metric: multiplier) }
                if squat >= 2.0 * bw { recordIfUnlocked(code: "strength_bw_squat_2_0", metric: multiplier) }
            }
            if let deadlift = workoutPRs.deadlift {
                let multiplier = (deadlift / bw * 100).rounded() / 100
                if deadlift >= 2.0 * bw { recordIfUnlocked(code: "strength_bw_deadlift_2_0", metric: multiplier) }
                if deadlift >= 2.5 * bw { recordIfUnlocked(code: "strength_bw_deadlift_2_5", metric: multiplier) }
            }
        }

        if let total = snapshotBig3Total(in: allFinishedWorkouts) {
            if total >= 300 { recordIfUnlocked(code: "strength_big3_total_300", metric: total) }
            if total >= 400 { recordIfUnlocked(code: "strength_big3_total_400", metric: total) }
            if total >= 500 { recordIfUnlocked(code: "strength_big3_total_500", metric: total) }
        }

        // 2. 累计总吨位（5 枚）
        let totalTonnage = allFinishedWorkouts.reduce(0) { $0 + $1.volumeKg }
        if totalTonnage >= 10_000 { recordIfUnlocked(code: "tonnage_10t", metric: totalTonnage) }
        if totalTonnage >= 50_000 { recordIfUnlocked(code: "tonnage_50t", metric: totalTonnage) }
        if totalTonnage >= 100_000 { recordIfUnlocked(code: "tonnage_100t", metric: totalTonnage) }
        if totalTonnage >= 500_000 { recordIfUnlocked(code: "tonnage_500t", metric: totalTonnage) }
        if totalTonnage >= 1_000_000 { recordIfUnlocked(code: "tonnage_1000t", metric: totalTonnage) }

        // 3. 纪律与历程（5 枚）
        let totalWorkouts = allFinishedWorkouts.count
        if totalWorkouts >= 1 { recordIfUnlocked(code: "career_first_workout", metric: Double(totalWorkouts)) }
        if totalWorkouts >= 10 { recordIfUnlocked(code: "career_10_workouts", metric: Double(totalWorkouts)) }
        if totalWorkouts >= 50 { recordIfUnlocked(code: "career_50_workouts", metric: Double(totalWorkouts)) }
        if totalWorkouts >= 100 { recordIfUnlocked(code: "career_100_workouts", metric: Double(totalWorkouts)) }
        if totalWorkouts >= 300 { recordIfUnlocked(code: "career_300_workouts", metric: Double(totalWorkouts)) }

        // 4. 单次战役极限（5 枚，严格由本次 workout 自身表现决定）
        let sessionVolume = workout.volumeKg
        if sessionVolume >= 10_000 { recordIfUnlocked(code: "feat_volume_10t", metric: sessionVolume) }
        if sessionVolume >= 20_000 { recordIfUnlocked(code: "feat_volume_20t", metric: sessionVolume) }

        let sessionCompletedSets = workout.completedSetCount
        if sessionCompletedSets >= 25 { recordIfUnlocked(code: "feat_dense_sets", metric: Double(sessionCompletedSets)) }

        let priorWorkouts = allFinishedWorkouts.filter { $0.id != workout.id && $0.startedAt < workout.startedAt }
        let brokenPRs = snapshotBrokenPRCount(in: workout, priorWorkouts: priorWorkouts)
        if brokenPRs >= 3 { recordIfUnlocked(code: "feat_triple_pr", metric: Double(brokenPRs)) }

        if perfectPlanExecution {
            recordIfUnlocked(code: "feat_perfect_plan", metric: 100.0)
        }

        return newCandidates
    }

    nonisolated private static func snapshotBig3PRs(in workouts: [BadgeWorkoutSnapshot]) -> (bench: Double?, squat: Double?, deadlift: Double?) {
        var best: [String: Double] = [:]
        for exercise in workouts.flatMap(\.exercises) {
            guard let lift = exercise.liftCode, let weight = exercise.maxWorkingWeight else { continue }
            best[lift] = max(best[lift] ?? weight, weight)
        }
        return (best["bench"], best["squat"], best["deadlift"])
    }

    nonisolated private static func snapshotBig3Total(in workouts: [BadgeWorkoutSnapshot]) -> Double? {
        let best = snapshotBig3PRs(in: workouts)
        guard let bench = best.bench, let squat = best.squat, let deadlift = best.deadlift else { return nil }
        return bench + squat + deadlift
    }

    nonisolated private static func snapshotBrokenPRCount(in workout: BadgeWorkoutSnapshot, priorWorkouts: [BadgeWorkoutSnapshot]) -> Int {
        // 三 PR 徽章沿用既有口径：比较完成正式组/递减段的重量，首次尝试不计。
        func weight(_ exercise: BadgeExerciseSnapshot) -> Double? {
            exercise.sets.filter { $0.completed && !$0.isWarmup }.flatMap { set in
                set.isDropSet ? set.segments.compactMap(\.weightKg) : [set.weightKg].compactMap { $0 }
            }.max()
        }
        var priorBest: [String: Double] = [:]
        for exercise in priorWorkouts.flatMap(\.exercises) {
            guard let value = weight(exercise) else { continue }
            priorBest[exercise.historyKey] = max(priorBest[exercise.historyKey] ?? value, value)
        }
        let assistance = priorWorkouts.flatMap(\.exercises).filter(\.isAssistedWeight).flatMap(\.assistancePerformances)
        var broken = Set<String>()
        for exercise in workout.exercises {
            if exercise.isAssistedWeight {
                if exercise.assistancePerformances.contains(where: { ExerciseWeightSemantics.isAssistanceBreakthrough($0, prior: assistance) }) {
                    broken.insert(exercise.historyKey)
                }
            } else if let value = weight(exercise), value > 0,
                      let prior = priorBest[exercise.historyKey], prior > 0, value > prior {
                broken.insert(exercise.historyKey)
            }
        }
        return broken.count
    }

    // MARK: - 存量历史时间线模拟（Backfill Pipeline）

    /// 按时间正序遍历用户全部历史训练，模拟完整时间线推导已解锁徽章存根列表
    /// - Parameters:
    ///   - sortedFinishedWorkouts: 按 startedAt 升序排列的历史完成训练
    ///   - existingGrants: 数据库中已存在的徽章（避免重复）
    ///   - currentWeight: 用户体重
    ///   - plans: 关联计划字典
    /// - Returns: 需要补写入数据库的全部新徽章存根候选
    @MainActor
    static func simulateHistoryTimeline(
        sortedFinishedWorkouts: [Workout],
        existingGrants: [BadgeGrant],
        currentWeight: Double?,
        plans: [UUID: WorkoutPlan] = [:]
    ) -> [BadgeGrantCandidate] {
        let workouts = sortedFinishedWorkouts.compactMap(snapshot)
        let planSnapshots = Dictionary(uniqueKeysWithValues: plans.values.map { ($0.localId, snapshot($0)) })
        return simulateHistoryTimeline(
            workouts: workouts,
            existingGrantCodes: Set(existingGrants.map(\.badgeCode)),
            plans: planSnapshots
        )
    }

    nonisolated private static func simulateHistoryTimeline(
        workouts: [BadgeWorkoutSnapshot],
        existingGrantCodes: Set<String>,
        plans: [UUID: BadgePlanSnapshot]
    ) -> [BadgeGrantCandidate] {
        var grants = existingGrantCodes
        var candidates: [BadgeGrantCandidate] = []
        var workoutCount = 0
        var totalTonnage = 0.0
        var big3Best: [String: Double] = [:]
        var bestByHistoryKey: [String: Double] = [:]
        var priorAssistance: [(date: Date, value: ExerciseWeightSemantics.Performance)] = []

        func append(_ code: String, metric: Double, workout: BadgeWorkoutSnapshot) {
            guard grants.insert(code).inserted else { return }
            candidates.append(BadgeGrantCandidate(
                badgeCode: code,
                unlockedAt: workout.endedAt,
                workoutId: workout.id,
                snapshotMetric: metric
            ))
        }

        for workout in workouts.sorted(by: { $0.startedAt < $1.startedAt }) {
            var brokenPRCount = 0
            var brokenPRKeys = Set<String>()
            var currentBestByHistoryKey: [String: Double] = [:]
            for exercise in workout.exercises {
                if exercise.isAssistedWeight {
                    let prior = priorAssistance.filter { $0.date < workout.startedAt }.map(\.value)
                    if exercise.assistancePerformances.contains(where: { ExerciseWeightSemantics.isAssistanceBreakthrough($0, prior: prior) }),
                       brokenPRKeys.insert(exercise.historyKey).inserted { brokenPRCount += 1 }
                    continue
                }
                guard let weight = exercise.maxWorkingWeight else { continue }
                currentBestByHistoryKey[exercise.historyKey] = max(currentBestByHistoryKey[exercise.historyKey] ?? weight, weight)
                if let previous = bestByHistoryKey[exercise.historyKey],
                   weight > previous,
                   brokenPRKeys.insert(exercise.historyKey).inserted {
                    brokenPRCount += 1
                }
                if let lift = exercise.liftCode {
                    big3Best[lift] = max(big3Best[lift] ?? weight, weight)
                }
            }

            if let bodyWeight = workout.bodyWeightKgAtCompletion, bodyWeight > 0 {
                let workoutBestByLift = Dictionary(grouping: workout.exercises.compactMap { exercise -> (String, Double)? in
                    guard let lift = exercise.liftCode, let weight = exercise.maxWorkingWeight else { return nil }
                    return (lift, weight)
                }, by: \.0).mapValues { $0.map(\.1).max() ?? 0 }
                if let bench = workoutBestByLift[Big3Lift.bench.rawValue] {
                    let multiplier = (bench / bodyWeight * 100).rounded() / 100
                    if bench >= bodyWeight { append("strength_bw_bench_1_0", metric: multiplier, workout: workout) }
                    if bench >= 1.5 * bodyWeight { append("strength_bw_bench_1_5", metric: multiplier, workout: workout) }
                }
                if let squat = workoutBestByLift[Big3Lift.squat.rawValue] {
                    let multiplier = (squat / bodyWeight * 100).rounded() / 100
                    if squat >= 1.5 * bodyWeight { append("strength_bw_squat_1_5", metric: multiplier, workout: workout) }
                    if squat >= 2 * bodyWeight { append("strength_bw_squat_2_0", metric: multiplier, workout: workout) }
                }
                if let deadlift = workoutBestByLift[Big3Lift.deadlift.rawValue] {
                    let multiplier = (deadlift / bodyWeight * 100).rounded() / 100
                    if deadlift >= 2 * bodyWeight { append("strength_bw_deadlift_2_0", metric: multiplier, workout: workout) }
                    if deadlift >= 2.5 * bodyWeight { append("strength_bw_deadlift_2_5", metric: multiplier, workout: workout) }
                }
            }

            if let bench = big3Best[Big3Lift.bench.rawValue],
               let squat = big3Best[Big3Lift.squat.rawValue],
               let deadlift = big3Best[Big3Lift.deadlift.rawValue] {
                let total = bench + squat + deadlift
                if total >= 300 { append("strength_big3_total_300", metric: total, workout: workout) }
                if total >= 400 { append("strength_big3_total_400", metric: total, workout: workout) }
                if total >= 500 { append("strength_big3_total_500", metric: total, workout: workout) }
            }

            workoutCount += 1
            totalTonnage += workout.volumeKg
            if totalTonnage >= 10_000 { append("tonnage_10t", metric: totalTonnage, workout: workout) }
            if totalTonnage >= 50_000 { append("tonnage_50t", metric: totalTonnage, workout: workout) }
            if totalTonnage >= 100_000 { append("tonnage_100t", metric: totalTonnage, workout: workout) }
            if totalTonnage >= 500_000 { append("tonnage_500t", metric: totalTonnage, workout: workout) }
            if totalTonnage >= 1_000_000 { append("tonnage_1000t", metric: totalTonnage, workout: workout) }

            if workoutCount >= 1 { append("career_first_workout", metric: Double(workoutCount), workout: workout) }
            if workoutCount >= 10 { append("career_10_workouts", metric: Double(workoutCount), workout: workout) }
            if workoutCount >= 50 { append("career_50_workouts", metric: Double(workoutCount), workout: workout) }
            if workoutCount >= 100 { append("career_100_workouts", metric: Double(workoutCount), workout: workout) }
            if workoutCount >= 300 { append("career_300_workouts", metric: Double(workoutCount), workout: workout) }

            if workout.volumeKg >= 10_000 { append("feat_volume_10t", metric: workout.volumeKg, workout: workout) }
            if workout.volumeKg >= 20_000 { append("feat_volume_20t", metric: workout.volumeKg, workout: workout) }
            if workout.completedSetCount >= 25 { append("feat_dense_sets", metric: Double(workout.completedSetCount), workout: workout) }
            if brokenPRCount >= 3 { append("feat_triple_pr", metric: Double(brokenPRCount), workout: workout) }
            if let planId = workout.planId,
               let plan = plans[planId],
               !plan.requiredSetsByItemId.isEmpty,
               workout.allSetsCompleted,
               plan.requiredSetsByItemId.allSatisfy({ itemId, requiredCount in
                   workout.exercises.first(where: { $0.planItemId == itemId })?.sets.filter(\.completed).count ?? 0 >= requiredCount
               }) {
                append("feat_perfect_plan", metric: 100, workout: workout)
            }

            for (key, weight) in currentBestByHistoryKey {
                bestByHistoryKey[key] = max(bestByHistoryKey[key] ?? weight, weight)
            }
            priorAssistance += workout.exercises.filter(\.isAssistedWeight).flatMap(\.assistancePerformances).map { (workout.startedAt, $0) }
        }
        return candidates
    }

    nonisolated private static func fingerprint(_ input: BadgeBackfillInput) -> String? {
        var parts = input.existingGrantCodes.sorted()
        for workout in input.workouts.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            parts.append(contentsOf: [
                workout.id.uuidString,
                workout.planId?.uuidString ?? "",
                String(workout.startedAt.timeIntervalSince1970),
                String(workout.endedAt.timeIntervalSince1970),
                String(workout.updatedAt.timeIntervalSince1970),
                workout.bodyWeightKgAtCompletion.map { String($0) } ?? ""
            ])
            for exercise in workout.exercises {
                parts.append(contentsOf: [exercise.historyKey, exercise.liftCode ?? "", exercise.planItemId?.uuidString ?? ""])
                for set in exercise.sets {
                    parts.append(contentsOf: [
                        set.weightKg.map { String($0) } ?? "",
                        set.reps.map { String($0) } ?? "",
                        String(set.completed),
                        String(set.isWarmup),
                        String(set.isDropSet)
                    ])
                    for segment in set.segments {
                        parts.append(segment.weightKg.map { String($0) } ?? "")
                        parts.append(segment.reps.map { String($0) } ?? "")
                    }
                }
            }
        }
        for plan in input.plans.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            parts.append(plan.id.uuidString)
            for requirement in plan.requirements {
                parts.append(requirement.itemId.uuidString)
                parts.append(String(requirement.requiredSetCount))
            }
        }
        let data = Data(parts.joined(separator: "|").utf8)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// 执行存量老用户历史数据回溯流水线（幂等保障）
    /// - Parameters:
    ///   - context: SwiftData ModelContext
    ///   - defaults: UserDefaults 存储
    ///   - force: 是否强制重新运行扫描（如 DEBUG 播种后）
    /// - Returns: 本次新插入的徽章候选列表
    @discardableResult
    @MainActor
    static func runBackfillIfNeeded(
        in context: ModelContext,
        defaults: UserDefaults = .standard,
        force: Bool = false,
        workoutSnapshots suppliedSnapshots: [BadgeWorkoutSnapshot]? = nil,
        ruleScope: String = "local"
    ) async -> [BadgeGrantCandidate] {
        let ruleKey = "badge.assistedWeightRules.v1.\(ruleScope)"
        let rebuilding = !defaults.bool(forKey: ruleKey)
        let grantDescriptor = FetchDescriptor<BadgeGrant>()
        guard let existingGrants = try? context.fetch(grantDescriptor) else { return [] }
        // 若全部 24 枚勋章均已解锁，无需再扫描
        if !rebuilding && existingGrants.count >= BadgeDefinition.all.count {
            defaults.set(true, forKey: backfillCompletedKey)
            return []
        }

        let workoutSnapshots: [BadgeWorkoutSnapshot]
        if let suppliedSnapshots { workoutSnapshots = suppliedSnapshots } else {
            let container = context.container
            guard let loaded = try? await Task.detached(priority: .utility, operation: {
                try await BadgeHistoryReader(modelContainer: container).readWorkouts()
            }).value else { return [] }
            workoutSnapshots = loaded
        }
        guard !Task.isCancelled else { return [] }
        if !rebuilding && workoutSnapshots.isEmpty {
            defaults.set(true, forKey: backfillCompletedKey)
            defaults.set(true, forKey: careerReviewShownKey)
            return []
        }

        let planDescriptor = FetchDescriptor<WorkoutPlan>(predicate: #Predicate { $0.deletedAt == nil })
        guard let allPlans = try? context.fetch(planDescriptor) else { return [] }
        let planSnapshots = allPlans.map(snapshot)
        let input = BadgeBackfillInput(
            workouts: workoutSnapshots,
            plans: planSnapshots,
            existingGrantCodes: existingGrants.map(\.badgeCode).sorted()
        )
        let inputFingerprint = await Task.detached(priority: .utility) {
            fingerprint(input)
        }.value
        if !force, !rebuilding,
           defaults.bool(forKey: backfillCompletedKey),
           inputFingerprint == defaults.string(forKey: backfillFingerprintKey) {
            return []
        }

        let planMap = Dictionary(uniqueKeysWithValues: planSnapshots.map { ($0.id, $0) })
        let existingCodes = rebuilding ? Set<String>() : Set(existingGrants.map(\.badgeCode))
        let candidates = await Task.detached(priority: .utility) {
            simulateHistoryTimeline(workouts: workoutSnapshots, existingGrantCodes: existingCodes, plans: planMap)
        }.value

        let finalInput = BadgeBackfillInput(workouts: workoutSnapshots, plans: planSnapshots,
                                          existingGrantCodes: Array(existingCodes.union(candidates.map(\.badgeCode))).sorted())
        let finalFingerprint = await Task.detached(priority: .utility) { fingerprint(finalInput) }.value

        guard let latestGrants = try? context.fetch(grantDescriptor) else { return [] }
        guard !Task.isCancelled else { return [] }
        // 不回滚调用方未保存的训练修改；先计算，随后在无挂起修改时原子替换。
        guard !context.hasChanges else { return [] }
        let latestCodes = rebuilding ? Set<String>() : Set(latestGrants.map(\.badgeCode))
        let newCandidates = candidates.filter { !latestCodes.contains($0.badgeCode) }
        if rebuilding { latestGrants.forEach { context.delete($0) } }
        var createdGrants: [BadgeGrant] = []
        for candidate in newCandidates {
            let grant = BadgeGrant(
                badgeCode: candidate.badgeCode,
                unlockedAt: candidate.unlockedAt,
                workoutId: candidate.workoutId,
                snapshotMetric: candidate.snapshotMetric
            )
            context.insert(grant)
            createdGrants.append(grant)
        }

        if rebuilding || !createdGrants.isEmpty {
            do { try context.save() } catch {
                context.rollback()
                return []
            }
            #if DEBUG
            print("[BadgeEngine] 存量回溯完成，已为老用户生成 \(createdGrants.count) 枚荣誉勋章")
            #endif
        }

        // 保存与版本标记之间不再挂起，避免账号切换或新任务介入提交窗口。
        if let finalFingerprint {
            defaults.set(finalFingerprint, forKey: backfillFingerprintKey)
        }
        defaults.set(true, forKey: backfillCompletedKey)
        defaults.set(true, forKey: ruleKey)

        return newCandidates
    }

    // MARK: - 徽章进度与详情计算（UI 呈现）

    /// 计算 24 枚徽章在当前历史状态下的达成度与进度描述
    static func calculateProgress(
        allFinishedWorkouts: [Workout],
        grants: [BadgeGrant],
        currentWeight: Double?
    ) -> [BadgeProgress] {
        calculateProgress(workouts: allFinishedWorkouts.compactMap { snapshot($0) }, grants: grants.map { grantSnapshot($0) }, currentWeight: currentWeight)
    }

    static func grantSnapshot(_ grant: BadgeGrant) -> BadgeGrantCandidate {
        BadgeGrantCandidate(badgeCode: grant.badgeCode, unlockedAt: grant.unlockedAt,
                            workoutId: grant.workoutId, snapshotMetric: grant.snapshotMetric)
    }

    nonisolated static func calculateProgress(
        workouts: [BadgeWorkoutSnapshot], grants: [BadgeGrantCandidate], currentWeight: Double?
    ) -> [BadgeProgress] {
        let grantMap = Dictionary(grants.map { ($0.badgeCode, $0) }, uniquingKeysWith: { first, _ in first })
        var best: [String: Double] = [:]
        var totalTonnage = 0.0
        var maxSingleVolume = 0.0
        var maxSingleSets = 0
        for workout in workouts {
            let volume = workout.volumeKg
            totalTonnage += volume
            maxSingleVolume = max(maxSingleVolume, volume)
            maxSingleSets = max(maxSingleSets, workout.completedSetCount)
            for exercise in workout.exercises {
                if let code = exercise.liftCode, let weight = exercise.maxWorkingWeight {
                    best[code] = max(best[code] ?? weight, weight)
                }
            }
        }
        let big3 = (bench: best["bench"], squat: best["squat"], deadlift: best["deadlift"])
        let totalBig3: Double? = best.count == 3 ? best.values.reduce(0, +) : nil
        let totalWorkouts = workouts.count

        return BadgeDefinition.all.map { definition in
            let grant = grantMap[definition.code]
            let isUnlocked = grant != nil

            var currentMetric: Double = 0
            var progressRatio: Double = 0
            var progressText: String = ""

            switch definition.code {
            // 一、力量三大项
            case "strength_bw_bench_1_0", "strength_bw_bench_1_5":
                let best = big3.bench ?? 0
                currentMetric = best
                if let bw = currentWeight, bw > 0 {
                    let ratio = best / bw
                    progressRatio = min(1.0, max(0.0, ratio / definition.targetValue))
                    let targetKg = definition.targetValue * bw
                    progressText = "\(formatKg(best)) / \(formatKg(targetKg)) kg（\(String(format: "%.1f", ratio)) / \(String(format: "%.1f", definition.targetValue)) 倍体重）"
                } else {
                    progressRatio = 0
                    progressText = "完善体重以开启"
                }

            case "strength_bw_squat_1_5", "strength_bw_squat_2_0":
                let best = big3.squat ?? 0
                currentMetric = best
                if let bw = currentWeight, bw > 0 {
                    let ratio = best / bw
                    progressRatio = min(1.0, max(0.0, ratio / definition.targetValue))
                    let targetKg = definition.targetValue * bw
                    progressText = "\(formatKg(best)) / \(formatKg(targetKg)) kg（\(String(format: "%.1f", ratio)) / \(String(format: "%.1f", definition.targetValue)) 倍体重）"
                } else {
                    progressRatio = 0
                    progressText = "完善体重以开启"
                }

            case "strength_bw_deadlift_2_0", "strength_bw_deadlift_2_5":
                let best = big3.deadlift ?? 0
                currentMetric = best
                if let bw = currentWeight, bw > 0 {
                    let ratio = best / bw
                    progressRatio = min(1.0, max(0.0, ratio / definition.targetValue))
                    let targetKg = definition.targetValue * bw
                    progressText = "\(formatKg(best)) / \(formatKg(targetKg)) kg（\(String(format: "%.1f", ratio)) / \(String(format: "%.1f", definition.targetValue)) 倍体重）"
                } else {
                    progressRatio = 0
                    progressText = "完善体重以开启"
                }

            case "strength_big3_total_300", "strength_big3_total_400", "strength_big3_total_500":
                let total = totalBig3 ?? 0
                currentMetric = total
                progressRatio = min(1.0, max(0.0, total / definition.targetValue))
                progressText = "\(formatKg(total)) / \(Int(definition.targetValue)) kg"

            // 二、总吨位
            case "tonnage_10t", "tonnage_50t", "tonnage_100t", "tonnage_500t", "tonnage_1000t":
                currentMetric = totalTonnage
                progressRatio = min(1.0, max(0.0, totalTonnage / definition.targetValue))
                progressText = "\(formatKg(totalTonnage)) / \(formatKg(definition.targetValue)) kg"

            // 三、纪律历程
            case "career_first_workout", "career_10_workouts", "career_50_workouts", "career_100_workouts", "career_300_workouts":
                currentMetric = Double(totalWorkouts)
                progressRatio = min(1.0, max(0.0, Double(totalWorkouts) / definition.targetValue))
                progressText = "\(totalWorkouts) / \(Int(definition.targetValue)) 次"

            // 四、单次战役极限
            case "feat_volume_10t", "feat_volume_20t":
                currentMetric = maxSingleVolume
                progressRatio = min(1.0, max(0.0, maxSingleVolume / definition.targetValue))
                progressText = "\(formatKg(maxSingleVolume)) / \(formatKg(definition.targetValue)) kg"

            case "feat_dense_sets":
                currentMetric = Double(maxSingleSets)
                progressRatio = min(1.0, max(0.0, Double(maxSingleSets) / definition.targetValue))
                progressText = "\(maxSingleSets) / \(Int(definition.targetValue)) 组"

            case "feat_triple_pr":
                currentMetric = isUnlocked ? 3 : 0
                progressRatio = isUnlocked ? 1.0 : 0.0
                progressText = isUnlocked ? "已突破 3 项" : "待单场破 3 项 PR"

            case "feat_perfect_plan":
                currentMetric = isUnlocked ? 100 : 0
                progressRatio = isUnlocked ? 1.0 : 0.0
                progressText = isUnlocked ? "已达成" : "待完成计划训练"

            default:
                break
            }

            if isUnlocked {
                progressRatio = 1.0
            }

            return BadgeProgress(
                definition: definition,
                isUnlocked: isUnlocked,
                currentMetric: currentMetric,
                targetMetric: definition.targetValue,
                grant: grant,
                progressRatio: progressRatio,
                progressText: progressText
            )
        }
    }

    nonisolated private static func formatKg(_ value: Double) -> String {
        if value >= 1_000_000 {
            let m = value / 1_000_000
            return String(format: "%.1fM", m)
        } else if value >= 10_000 {
            let k = value / 1_000
            return String(format: "%.0fk", k)
        } else if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        } else {
            return String(format: "%.1f", value)
        }
    }
}
