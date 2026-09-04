import Foundation
import SwiftData
import Testing
@testable import DontLift

struct BadgeEngineTests {

    // MARK: - 辅助测试构建器

    private static func makeExercise(
        code: String?,
        name: String,
        weight: Double,
        reps: Int = 1,
        setsCount: Int = 1,
        customId: UUID? = nil,
        isWarmup: Bool = false,
        planItemId: UUID? = nil
    ) -> WorkoutExercise {
        let ex = WorkoutExercise(
            builtinExerciseCode: code,
            customExerciseId: customId,
            exerciseName: name,
            orderIndex: 0,
            planItemId: planItemId
        )
        ex.sets = (0..<setsCount).map { index in
            WorkoutSet(
                setIndex: index,
                weightKg: weight,
                reps: reps,
                completed: true,
                setType: .working,
                isWarmup: isWarmup
            )
        }
        return ex
    }

    private static func makeWorkout(
        exercises: [WorkoutExercise],
        startedAt: Date = .now,
        endedAt: Date? = .now,
        planId: UUID? = nil
    ) -> Workout {
        let w = Workout(
            planId: planId,
            startedAt: startedAt,
            endedAt: endedAt,
            exercises: exercises
        )
        for ex in exercises { ex.workout = w }
        return w
    }

    // MARK: - 1. 三大项识别与 IPF 标准测试

    @Test func big3IdentificationStrictStandard() {
        // 标准杠铃卧推、深蹲、常规硬拉、相扑硬拉
        let bench = Self.makeExercise(code: "BB_BENCH_PRESS", name: "杠铃卧推", weight: 100)
        let squat = Self.makeExercise(code: "BB_SQUAT", name: "杠铃深蹲", weight: 140)
        let dl = Self.makeExercise(code: "DEADLIFT", name: "硬拉", weight: 180)
        let sumoDl = Self.makeExercise(code: "SUMO_DEADLIFT", name: "相扑硬拉", weight: 200)

        #expect(Big3Lift.identify(exercise: bench) == .bench)
        #expect(Big3Lift.identify(exercise: squat) == .squat)
        #expect(Big3Lift.identify(exercise: dl) == .deadlift)
        #expect(Big3Lift.identify(exercise: sumoDl) == .deadlift)

        // 史密斯、哑铃、器械、自定义等变式动作严格排除
        let smithBench = Self.makeExercise(code: "SMITH_BENCH_PRESS", name: "史密斯机卧推", weight: 120)
        let dbBench = Self.makeExercise(code: "DB_BENCH_PRESS", name: "哑铃卧推", weight: 40)
        let hackSquat = Self.makeExercise(code: "HACK_SQUAT", name: "哈克深蹲", weight: 160)
        let customEx = Self.makeExercise(code: "BB_SQUAT", name: "自制深蹲", weight: 150, customId: UUID())

        #expect(Big3Lift.identify(exercise: smithBench) == nil)
        #expect(Big3Lift.identify(exercise: dbBench) == nil)
        #expect(Big3Lift.identify(exercise: hackSquat) == nil)
        #expect(Big3Lift.identify(exercise: customEx) == nil)
    }

    @Test func deadliftConventionalAndSumoTakesMax() {
        let ex1 = Self.makeExercise(code: "DEADLIFT", name: "硬拉", weight: 180)
        let ex2 = Self.makeExercise(code: "SUMO_DEADLIFT", name: "相扑硬拉", weight: 195)
        let w = Self.makeWorkout(exercises: [ex1, ex2])

        let maxDl = BadgeEngine.maxWeight(in: w, for: .deadlift)
        #expect(maxDl == 195)
    }

    // MARK: - 2. 体重防护与倍数勋章判定

    @Test func bodyweightMultiplierBadgesWithAndWithoutWeight() {
        let bench = Self.makeExercise(code: "BB_BENCH_PRESS", name: "杠铃卧推", weight: 105) // 1.5x of 70kg
        let squat = Self.makeExercise(code: "BB_SQUAT", name: "杠铃深蹲", weight: 140) // 2.0x of 70kg
        let dl = Self.makeExercise(code: "DEADLIFT", name: "硬拉", weight: 175) // 2.5x of 70kg
        let w = Self.makeWorkout(exercises: [bench, squat, dl])

        // 边界防护：未录入体重时，严禁解锁任何体重倍数勋章
        let unweightedResults = BadgeEngine.evaluateIncremental(
            workout: w,
            allFinishedWorkouts: [w],
            currentGrants: [],
            currentWeight: nil
        )
        let unweightedBwCodes = unweightedResults.map(\.badgeCode).filter { $0.starts(with: "strength_bw_") }
        #expect(unweightedBwCodes.isEmpty)

        // 录入 70kg 体重：应达成全部 6 枚体重倍数徽章
        let weightedResults = BadgeEngine.evaluateIncremental(
            workout: w,
            allFinishedWorkouts: [w],
            currentGrants: [],
            currentWeight: 70.0
        )
        let bwCodes = Set(weightedResults.map(\.badgeCode))
        #expect(bwCodes.contains("strength_bw_bench_1_0"))
        #expect(bwCodes.contains("strength_bw_bench_1_5"))
        #expect(bwCodes.contains("strength_bw_squat_1_5"))
        #expect(bwCodes.contains("strength_bw_squat_2_0"))
        #expect(bwCodes.contains("strength_bw_deadlift_2_0"))
        #expect(bwCodes.contains("strength_bw_deadlift_2_5"))
    }

    // MARK: - 3. 三大项俱乐部总和判定

    @Test func big3ClubTotalRequiresAllThreeLifts() {
        // 只有两项：深蹲 180 + 卧推 140 = 320kg（缺硬拉）
        let squat = Self.makeExercise(code: "BB_SQUAT", name: "杠铃深蹲", weight: 180)
        let bench = Self.makeExercise(code: "BB_BENCH_PRESS", name: "杠铃卧推", weight: 140)
        let incompleteW = Self.makeWorkout(exercises: [squat, bench])

        #expect(BadgeEngine.big3Total(in: [incompleteW]) == nil)
        let incompleteResults = BadgeEngine.evaluateIncremental(
            workout: incompleteW,
            allFinishedWorkouts: [incompleteW],
            currentGrants: [],
            currentWeight: 75.0
        )
        let totalCodes = incompleteResults.map(\.badgeCode).filter { $0.starts(with: "strength_big3_total_") }
        #expect(totalCodes.isEmpty)

        // 补上硬拉 200kg：总和 520kg，跨越 300、400、500 俱乐部
        let dl = Self.makeExercise(code: "DEADLIFT", name: "硬拉", weight: 200)
        let completeW = Self.makeWorkout(exercises: [squat, bench, dl])

        #expect(BadgeEngine.big3Total(in: [completeW]) == 520)
        let completeResults = BadgeEngine.evaluateIncremental(
            workout: completeW,
            allFinishedWorkouts: [completeW],
            currentGrants: [],
            currentWeight: 75.0
        )
        let unlockedTotals = Set(completeResults.map(\.badgeCode))
        #expect(unlockedTotals.contains("strength_big3_total_300"))
        #expect(unlockedTotals.contains("strength_big3_total_400"))
        #expect(unlockedTotals.contains("strength_big3_total_500"))
    }

    // MARK: - 4. 累计吨位与纪律历程判定

    @Test func cumulativeTonnageAndCareerMilestones() {
        // 单场 10 组 100kg x 10次 = 10,000kg
        let ex = Self.makeExercise(code: "BB_BENCH_PRESS", name: "卧推", weight: 100, reps: 10, setsCount: 10)
        let w1 = Self.makeWorkout(exercises: [ex])

        let results1 = BadgeEngine.evaluateIncremental(
            workout: w1,
            allFinishedWorkouts: [w1],
            currentGrants: [],
            currentWeight: nil
        )
        let codes1 = Set(results1.map(\.badgeCode))
        #expect(codes1.contains("career_first_workout"))
        #expect(codes1.contains("tonnage_10t"))
        #expect(codes1.contains("feat_volume_10t")) // 单场万吨同时触发

        // 模拟累计 10 次训练，总吨位达到 100,000kg
        var allWorkouts: [Workout] = [w1]
        for _ in 1..<10 {
            let nextEx = Self.makeExercise(code: "BB_BENCH_PRESS", name: "卧推", weight: 100, reps: 10, setsCount: 10)
            allWorkouts.append(Self.makeWorkout(exercises: [nextEx]))
        }
        let w10 = allWorkouts.last!
        let results10 = BadgeEngine.evaluateIncremental(
            workout: w10,
            allFinishedWorkouts: allWorkouts,
            currentGrants: codes1,
            currentWeight: nil
        )
        let codes10 = Set(results10.map(\.badgeCode))
        #expect(codes10.contains("career_10_workouts"))
        #expect(codes10.contains("tonnage_50t"))
        #expect(codes10.contains("tonnage_100t"))
    }

    // MARK: - 5. 单次极限：铁血容量、3 PR 与严丝合缝计划

    @Test func singleWorkoutFeatsEvaluation() {
        // A. 铁血容量 (>= 25 组) & 力竭深渊 (>= 20,000kg)
        // 25 组 100kg x 10 次 = 25,000kg
        let exDense = Self.makeExercise(code: "BB_SQUAT", name: "深蹲", weight: 100, reps: 10, setsCount: 25)
        let wDense = Self.makeWorkout(exercises: [exDense])

        let resultsDense = BadgeEngine.evaluateIncremental(
            workout: wDense,
            allFinishedWorkouts: [wDense],
            currentGrants: [],
            currentWeight: nil
        )
        let codesDense = Set(resultsDense.map(\.badgeCode))
        #expect(codesDense.contains("feat_dense_sets"))
        #expect(codesDense.contains("feat_volume_20t"))

        // B. 势如破竹 (打破 >= 3 项历史 PR)
        // 历史前序训练：A 动作 50kg，B 动作 60kg，C 动作 70kg
        let exA0 = Self.makeExercise(code: "EX_A", name: "动作A", weight: 50)
        let exB0 = Self.makeExercise(code: "EX_B", name: "动作B", weight: 60)
        let exC0 = Self.makeExercise(code: "EX_C", name: "动作C", weight: 70)
        let priorW = Self.makeWorkout(exercises: [exA0, exB0, exC0], startedAt: .now.addingTimeInterval(-3600))

        // 本次训练：A 动作 55kg，B 动作 65kg，C 动作 75kg（均打破历史）
        let exA1 = Self.makeExercise(code: "EX_A", name: "动作A", weight: 55)
        let exB1 = Self.makeExercise(code: "EX_B", name: "动作B", weight: 65)
        let exC1 = Self.makeExercise(code: "EX_C", name: "动作C", weight: 75)
        let breakW = Self.makeWorkout(exercises: [exA1, exB1, exC1], startedAt: .now)

        let breakResults = BadgeEngine.evaluateIncremental(
            workout: breakW,
            allFinishedWorkouts: [priorW, breakW],
            currentGrants: [],
            currentWeight: nil
        )
        let breakCodes = Set(breakResults.map(\.badgeCode))
        #expect(breakCodes.contains("feat_triple_pr"))

        // C. 严丝合缝计划 (100% 达成计划项)
        let planItemId = UUID()
        let planItem = PlanItem(
            itemId: planItemId,
            exerciseName: "计划卧推",
            orderIndex: 0,
            suggestedSets: 3
        )
        let plan = WorkoutPlan(name: "测试计划", items: [planItem])

        // 训练中完全执行了该 planItemId 的 3 组
        let planEx = Self.makeExercise(code: "BB_BENCH_PRESS", name: "杠铃卧推", weight: 80, reps: 5, setsCount: 3, planItemId: planItemId)
        let planW = Self.makeWorkout(exercises: [planEx], planId: plan.localId)

        let planResults = BadgeEngine.evaluateIncremental(
            workout: planW,
            allFinishedWorkouts: [planW],
            currentGrants: [],
            currentWeight: nil,
            plan: plan
        )
        let planCodes = Set(planResults.map(\.badgeCode))
        #expect(planCodes.contains("feat_perfect_plan"))
    }

    // MARK: - 6. 存量回溯与幂等性验证

    @Test @MainActor func backfillPipelineAndIdempotency() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let testDefaults = UserDefaults(suiteName: "BadgeEngineTests.\(UUID().uuidString)")!

        // 插入 2 次历史训练
        let w1 = Self.makeWorkout(
            exercises: [Self.makeExercise(code: "BB_BENCH_PRESS", name: "卧推", weight: 100, reps: 10, setsCount: 10)],
            startedAt: Date(timeIntervalSince1970: 1000),
            endedAt: Date(timeIntervalSince1970: 4600)
        )
        let w2 = Self.makeWorkout(
            exercises: [Self.makeExercise(code: "BB_SQUAT", name: "深蹲", weight: 120, reps: 10, setsCount: 10)],
            startedAt: Date(timeIntervalSince1970: 10000),
            endedAt: Date(timeIntervalSince1970: 13600)
        )
        context.insert(w1)
        context.insert(w2)
        try context.save()

        // 首次执行 Backfill
        let createdFirst = BadgeEngine.runBackfillIfNeeded(in: context, defaults: testDefaults)
        #expect(!createdFirst.isEmpty)
        #expect(testDefaults.bool(forKey: BadgeEngine.backfillCompletedKey) == true)

        let grantDescriptor = FetchDescriptor<BadgeGrant>()
        let savedGrants = try context.fetch(grantDescriptor)
        #expect(savedGrants.count == createdFirst.count)

        // 检查首练徽章的关联 workoutId 精确对应 w1
        let firstWorkoutGrant = savedGrants.first { $0.badgeCode == "career_first_workout" }
        #expect(firstWorkoutGrant?.workoutId == w1.localId)

        // 二次执行 Backfill：幂等保护，不再生成任何新徽章
        let createdSecond = BadgeEngine.runBackfillIfNeeded(in: context, defaults: testDefaults)
        #expect(createdSecond.isEmpty)
    }

    // MARK: - 7. 徽章进度展示计算

    @Test func progressCalculationOutputsCorrectDisplay() {
        let bench = Self.makeExercise(code: "BB_BENCH_PRESS", name: "卧推", weight: 70)
        let w = Self.makeWorkout(exercises: [bench])

        // 无体重时展示引导
        let unweightedProgress = BadgeEngine.calculateProgress(
            allFinishedWorkouts: [w],
            grants: [],
            currentWeight: nil
        )
        let benchProgressNoWeight = unweightedProgress.first { $0.definition.code == "strength_bw_bench_1_0" }
        #expect(benchProgressNoWeight?.progressText == "完善体重以开启")
        #expect(benchProgressNoWeight?.progressRatio == 0)

        // 有体重 70kg 时展示正确比例 100%
        let weightedProgress = BadgeEngine.calculateProgress(
            allFinishedWorkouts: [w],
            grants: [],
            currentWeight: 70.0
        )
        let benchProgressWithWeight = weightedProgress.first { $0.definition.code == "strength_bw_bench_1_0" }
        #expect(benchProgressWithWeight?.progressRatio == 1.0)
    }
}
