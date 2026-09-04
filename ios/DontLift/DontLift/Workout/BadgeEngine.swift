import Foundation
import SwiftData

/// 候选解锁成就（未持久化内存模型）
struct BadgeGrantCandidate: Equatable, Hashable {
    let badgeCode: String
    let unlockedAt: Date
    let workoutId: UUID?
    let snapshotMetric: Double
}

/// 徽章当前达成进度（供徽章馆与个人中心展示）
struct BadgeProgress: Equatable {
    let definition: BadgeDefinition
    let isUnlocked: Bool
    let currentMetric: Double
    let targetMetric: Double
    let grant: BadgeGrant?
    let progressRatio: Double
    let progressText: String
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

        guard let plan, !plan.items.isEmpty else {
            // 若计划对象因删除等原因不可查，则基于本次训练动作均有组完成判定
            return workout.completedStatEntryCount > 0
        }

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

    // MARK: - 纯函数式徽章评估（增量单次训练结算）

    /// 评估单次训练结算触发的新徽章
    /// - Parameters:
    ///   - workout: 刚刚完成的训练（已置位 `endedAt != nil`）
    ///   - allFinishedWorkouts: 包含本次在内的全部历史有效完成训练
    ///   - currentGrants: 当前已获得的徽章 code 集合
    ///   - currentWeight: 用户当前体重（若未录入则传入 nil）
    ///   - plan: 本次训练对应的计划对象（可选）
    /// - Returns: 本次新达成的徽章候选列表
    static func evaluateIncremental(
        workout: Workout,
        allFinishedWorkouts: [Workout],
        currentGrants: Set<String>,
        currentWeight: Double?,
        plan: WorkoutPlan? = nil
    ) -> [BadgeGrantCandidate] {
        var newCandidates: [BadgeGrantCandidate] = []
        let unlockedAt = workout.endedAt ?? workout.startedAt
        let workoutId = workout.localId

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
        let prs = big3PRs(in: allFinishedWorkouts)
        if let bw = currentWeight, bw > 0 {
            if let bench = prs.bench {
                let multiplier = (bench / bw * 100).rounded() / 100
                if bench >= 1.0 * bw { recordIfUnlocked(code: "strength_bw_bench_1_0", metric: multiplier) }
                if bench >= 1.5 * bw { recordIfUnlocked(code: "strength_bw_bench_1_5", metric: multiplier) }
            }
            if let squat = prs.squat {
                let multiplier = (squat / bw * 100).rounded() / 100
                if squat >= 1.5 * bw { recordIfUnlocked(code: "strength_bw_squat_1_5", metric: multiplier) }
                if squat >= 2.0 * bw { recordIfUnlocked(code: "strength_bw_squat_2_0", metric: multiplier) }
            }
            if let deadlift = prs.deadlift {
                let multiplier = (deadlift / bw * 100).rounded() / 100
                if deadlift >= 2.0 * bw { recordIfUnlocked(code: "strength_bw_deadlift_2_0", metric: multiplier) }
                if deadlift >= 2.5 * bw { recordIfUnlocked(code: "strength_bw_deadlift_2_5", metric: multiplier) }
            }
        }

        if let total = big3Total(in: allFinishedWorkouts) {
            if total >= 300 { recordIfUnlocked(code: "strength_big3_total_300", metric: total) }
            if total >= 400 { recordIfUnlocked(code: "strength_big3_total_400", metric: total) }
            if total >= 500 { recordIfUnlocked(code: "strength_big3_total_500", metric: total) }
        }

        // 2. 累计总吨位（5 枚）
        let totalTonnage = cumulativeTonnage(in: allFinishedWorkouts)
        if totalTonnage >= 10_000 { recordIfUnlocked(code: "tonnage_10t", metric: totalTonnage) }
        if totalTonnage >= 50_000 { recordIfUnlocked(code: "tonnage_50t", metric: totalTonnage) }
        if totalTonnage >= 100_000 { recordIfUnlocked(code: "tonnage_100t", metric: totalTonnage) }
        if totalTonnage >= 500_000 { recordIfUnlocked(code: "tonnage_500t", metric: totalTonnage) }
        if totalTonnage >= 1_000_000 { recordIfUnlocked(code: "tonnage_1000t", metric: totalTonnage) }

        // 3. 纪律与历程（5 枚）
        let totalWorkouts = completedWorkoutCount(in: allFinishedWorkouts)
        if totalWorkouts >= 1 { recordIfUnlocked(code: "career_first_workout", metric: Double(totalWorkouts)) }
        if totalWorkouts >= 10 { recordIfUnlocked(code: "career_10_workouts", metric: Double(totalWorkouts)) }
        if totalWorkouts >= 50 { recordIfUnlocked(code: "career_50_workouts", metric: Double(totalWorkouts)) }
        if totalWorkouts >= 100 { recordIfUnlocked(code: "career_100_workouts", metric: Double(totalWorkouts)) }
        if totalWorkouts >= 300 { recordIfUnlocked(code: "career_300_workouts", metric: Double(totalWorkouts)) }

        // 4. 单次战役极限（5 枚，严格由本次 workout 自身表现决定）
        let sessionVolume = workout.completedStatVolumeKg
        if sessionVolume >= 10_000 { recordIfUnlocked(code: "feat_volume_10t", metric: sessionVolume) }
        if sessionVolume >= 20_000 { recordIfUnlocked(code: "feat_volume_20t", metric: sessionVolume) }

        let sessionCompletedSets = workout.completedStatEntryCount
        if sessionCompletedSets >= 25 { recordIfUnlocked(code: "feat_dense_sets", metric: Double(sessionCompletedSets)) }

        let priorWorkouts = allFinishedWorkouts.filter { $0.localId != workout.localId && $0.startedAt < workout.startedAt }
        let brokenPRs = detectBrokenPRCount(in: workout, priorWorkouts: priorWorkouts)
        if brokenPRs >= 3 { recordIfUnlocked(code: "feat_triple_pr", metric: Double(brokenPRs)) }

        if isPerfectPlanExecution(workout: workout, plan: plan) {
            recordIfUnlocked(code: "feat_perfect_plan", metric: 100.0)
        }

        return newCandidates
    }

    // MARK: - 存量历史时间线模拟（Backfill Pipeline）

    /// 按时间正序遍历用户全部历史训练，模拟完整时间线推导已解锁徽章存根列表
    /// - Parameters:
    ///   - sortedFinishedWorkouts: 按 startedAt 升序排列的历史完成训练
    ///   - existingGrants: 数据库中已存在的徽章（避免重复）
    ///   - currentWeight: 用户体重
    ///   - plans: 关联计划字典
    /// - Returns: 需要补写入数据库的全部新徽章存根候选
    static func simulateHistoryTimeline(
        sortedFinishedWorkouts: [Workout],
        existingGrants: [BadgeGrant],
        currentWeight: Double?,
        plans: [UUID: WorkoutPlan] = [:]
    ) -> [BadgeGrantCandidate] {
        var runningGrants = Set(existingGrants.map(\.badgeCode))
        var accumulatedCandidates: [BadgeGrantCandidate] = []
        var runningHistory: [Workout] = []

        for workout in sortedFinishedWorkouts {
            runningHistory.append(workout)
            let plan = workout.planId.flatMap { plans[$0] }
            let newlyUnlocked = evaluateIncremental(
                workout: workout,
                allFinishedWorkouts: runningHistory,
                currentGrants: runningGrants,
                currentWeight: currentWeight,
                plan: plan
            )
            for candidate in newlyUnlocked {
                runningGrants.insert(candidate.badgeCode)
                accumulatedCandidates.append(candidate)
            }
        }

        return accumulatedCandidates
    }

    /// 执行存量老用户历史数据回溯流水线（幂等保障）
    /// - Parameters:
    ///   - context: SwiftData ModelContext
    ///   - defaults: UserDefaults 存储
    ///   - force: 是否强制重新运行扫描（如 DEBUG 播种后）
    /// - Returns: 本次新插入的 BadgeGrant 列表
    @discardableResult
    @MainActor
    static func runBackfillIfNeeded(
        in context: ModelContext,
        defaults: UserDefaults = .standard,
        force: Bool = false
    ) -> [BadgeGrant] {
        if !force && defaults.bool(forKey: backfillCompletedKey) {
            return []
        }

        let workoutDescriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .forward)]
        )
        guard let rawWorkouts = try? context.fetch(workoutDescriptor) else {
            return []
        }
        let allWorkouts = rawWorkouts.filter { $0.endedAt != nil }

        let grantDescriptor = FetchDescriptor<BadgeGrant>()
        let existingGrants = (try? context.fetch(grantDescriptor)) ?? []

        let planDescriptor = FetchDescriptor<WorkoutPlan>(predicate: #Predicate { $0.deletedAt == nil })
        let allPlans = (try? context.fetch(planDescriptor)) ?? []
        let planMap = Dictionary(uniqueKeysWithValues: allPlans.map { ($0.localId, $0) })

        let currentWeight = WorkoutCaloriePreferences.current(defaults: defaults).bodyWeightKg

        let candidates = simulateHistoryTimeline(
            sortedFinishedWorkouts: allWorkouts,
            existingGrants: existingGrants,
            currentWeight: currentWeight,
            plans: planMap
        )

        var createdGrants: [BadgeGrant] = []
        for candidate in candidates {
            let grant = BadgeGrant(
                badgeCode: candidate.badgeCode,
                unlockedAt: candidate.unlockedAt,
                workoutId: candidate.workoutId,
                snapshotMetric: candidate.snapshotMetric
            )
            context.insert(grant)
            createdGrants.append(grant)
        }

        if !createdGrants.isEmpty {
            try? context.save()
            #if DEBUG
            print("[BadgeEngine] 存量回溯完成，已为老用户生成 \(createdGrants.count) 枚荣誉勋章")
            #endif
        }

        defaults.set(true, forKey: backfillCompletedKey)
        // 若老用户没有任何历史完成训练，直接静默置位已看过生涯回顾，避免对新用户弹出空回顾
        if allWorkouts.isEmpty {
            defaults.set(true, forKey: careerReviewShownKey)
        }

        return createdGrants
    }

    // MARK: - 徽章进度与详情计算（UI 呈现）

    /// 计算 24 枚徽章在当前历史状态下的达成度与进度描述
    static func calculateProgress(
        allFinishedWorkouts: [Workout],
        grants: [BadgeGrant],
        currentWeight: Double?
    ) -> [BadgeProgress] {
        let grantMap = Dictionary(uniqueKeysWithValues: grants.map { ($0.badgeCode, $0) })
        let big3 = big3PRs(in: allFinishedWorkouts)
        let totalTonnage = cumulativeTonnage(in: allFinishedWorkouts)
        let totalWorkouts = completedWorkoutCount(in: allFinishedWorkouts)
        let totalBig3 = big3Total(in: allFinishedWorkouts)

        // 单次战役单项极限极值
        let maxSingleVolume = allFinishedWorkouts.map(\.completedStatVolumeKg).max() ?? 0
        let maxSingleSets = allFinishedWorkouts.map(\.completedStatEntryCount).max() ?? 0

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
                    progressText = "\(formatKg(best)) / \(formatKg(targetKg)) kg (\(String(format: "%.1f", ratio)) / \(String(format: "%.1f", definition.targetValue))x)"
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
                    progressText = "\(formatKg(best)) / \(formatKg(targetKg)) kg (\(String(format: "%.1f", ratio)) / \(String(format: "%.1f", definition.targetValue))x)"
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
                    progressText = "\(formatKg(best)) / \(formatKg(targetKg)) kg (\(String(format: "%.1f", ratio)) / \(String(format: "%.1f", definition.targetValue))x)"
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

    private static func formatKg(_ value: Double) -> String {
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
