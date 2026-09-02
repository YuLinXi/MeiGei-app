#if DEBUG
import Foundation
import SwiftData

/// DEBUG-only 演示数据生成器：为 Simulator 测试账号一键生成近 6 周真实场景训练数据。
///
/// 覆盖：多肌群（胸/背/腿/肩/手臂/臀/核心）、周渐进（主项每周 +2.5kg）、热身组、
/// 递减组、超级组、动作/整体备注、两个计划（自适应「推拉分化」+ 严格「腿部力量」）。
/// 生成的是普通本地记录（pendingCreate），会随下次同步上传 dev 后端。
enum WorkoutDemoSeedData {
    struct Result: Equatable {
        var workouts: Int
        var plans: Int
    }

    private struct Lift {
        let code: String
        let name: String
        let muscle: String
        let baseWeight: Double      // 第 1 周起步重量
        let weeklyStep: Double      // 周渐进
        let sets: Int
        let reps: Int
    }

    // 全部取自内置动作库已确认存在的条目。
    private static let benchPress = Lift(code: "HAMMER_BENCH_PRESS", name: "悍马机卧推", muscle: "胸",
                                         baseWeight: 60, weeklyStep: 2.5, sets: 4, reps: 8)
    private static let fly = Lift(code: "FLAT_DB_FLY", name: "平躺哑铃飞鸟", muscle: "胸",
                                  baseWeight: 12.5, weeklyStep: 1.25, sets: 3, reps: 10)
    private static let pulldown = Lift(code: "NEUTRAL_GRIP_PULLDOWN", name: "对握高位下拉", muscle: "背",
                                       baseWeight: 55, weeklyStep: 2.5, sets: 4, reps: 8)
    private static let row = Lift(code: "BB_SEAL_ROW", name: "海豹杠铃划船", muscle: "背",
                                  baseWeight: 50, weeklyStep: 2.5, sets: 4, reps: 8)
    private static let squat = Lift(code: "TRAP_BAR_SQUAT", name: "六角杠深蹲", muscle: "腿",
                                    baseWeight: 70, weeklyStep: 2.5, sets: 4, reps: 6)
    private static let legPress = Lift(code: "LYING_LEG_PRESS", name: "连动式仰卧腿举", muscle: "腿",
                                       baseWeight: 100, weeklyStep: 5, sets: 3, reps: 10)
    private static let rdl = Lift(code: "MACHINE_ROMANIAN_DL", name: "挂片式罗马尼亚硬拉", muscle: "腿",
                                  baseWeight: 50, weeklyStep: 2.5, sets: 3, reps: 10)
    private static let ohp = Lift(code: "DB_OVERHEAD_PRESS", name: "哑铃推肩", muscle: "肩",
                                  baseWeight: 20, weeklyStep: 1.25, sets: 4, reps: 8)
    private static let curl = Lift(code: "BB_EZ_BAR_CURL", name: "EZ杆二头弯举", muscle: "手臂",
                                   baseWeight: 20, weeklyStep: 1.25, sets: 3, reps: 10)
    private static let pushdown = Lift(code: "BB_TRICEP_PUSHDOWN_SZ_BAR", name: "绳索三头下压_SZ杆", muscle: "手臂",
                                       baseWeight: 25, weeklyStep: 1.25, sets: 3, reps: 10)
    private static let hipThrust = Lift(code: "MACHINE_HIP_THRUST", name: "器械臀冲", muscle: "臀",
                                        baseWeight: 60, weeklyStep: 5, sets: 3, reps: 10)
    private static let crunch = Lift(code: "SEATED_MACHINE_CRUNCH", name: "坐姿器械卷腹", muscle: "核心",
                                     baseWeight: 30, weeklyStep: 1.25, sets: 3, reps: 12)

    @discardableResult
    @MainActor
    static func seed(in context: ModelContext) throws -> Result {
        let calendar = Calendar.currentMondayFirst
        let thisWeekStart = WorkoutWeeklyStats.weekBounds(for: .now, calendar: calendar).start

        // 两个计划：自适应「推拉分化」（含整体备注、动作备注、默认休息）+ 严格「腿部力量」。
        let pushPull = WorkoutPlan(name: "推拉分化", note: "上肢推拉隔日，主项每周加 2.5kg；状态差就回退一周重量。",
                                   mode: .adaptive, sortOrder: 0)
        pushPull.items = [
            PlanItem(builtinExerciseCode: benchPress.code, exerciseName: benchPress.name,
                     primaryMuscle: benchPress.muscle, orderIndex: 0,
                     suggestedSets: 4, suggestedReps: 8, suggestedWeightKg: 60,
                     restAfterSetSeconds: 120, note: "顶峰收缩 1 秒，下落控制 2 秒"),
            PlanItem(builtinExerciseCode: pulldown.code, exerciseName: pulldown.name,
                     primaryMuscle: pulldown.muscle, orderIndex: 1,
                     suggestedSets: 4, suggestedReps: 8, suggestedWeightKg: 55,
                     restAfterSetSeconds: 90),
            PlanItem(builtinExerciseCode: ohp.code, exerciseName: ohp.name,
                     primaryMuscle: ohp.muscle, orderIndex: 2,
                     suggestedSets: 4, suggestedReps: 8, suggestedWeightKg: 20,
                     restAfterSetSeconds: 90, note: "核心收紧，不要借力")
        ]
        let legDay = WorkoutPlan(name: "腿部力量", mode: .strict, sortOrder: 1)
        legDay.items = [
            PlanItem(builtinExerciseCode: squat.code, exerciseName: squat.name,
                     primaryMuscle: squat.muscle, orderIndex: 0,
                     suggestedSets: 4, suggestedReps: 6, suggestedWeightKg: 70,
                     restAfterSetSeconds: 150),
            PlanItem(builtinExerciseCode: legPress.code, exerciseName: legPress.name,
                     primaryMuscle: legPress.muscle, orderIndex: 1,
                     suggestedSets: 3, suggestedReps: 10, suggestedWeightKg: 100,
                     restAfterSetSeconds: 120)
        ]
        context.insert(pushPull)
        context.insert(legDay)

        // 近 6 周，每周 4 练：周一 胸+手臂、周三 背+肩、周五 腿+臀、周日 胸+核心（轻）。
        let weekOffsets = stride(from: -5, through: 0, by: 1)
        for weekOffset in weekOffsets {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: thisWeekStart) else { continue }
            let weekIndex = weekOffset + 5   // 0...5，用于重量渐进
            seedChestArmsDay(at: day(weekStart, 0), weekIndex: weekIndex, planId: pushPull.localId, in: context)
            seedBackShoulderDay(at: day(weekStart, 2), weekIndex: weekIndex, planId: pushPull.localId, in: context)
            seedLegGluteDay(at: day(weekStart, 4), weekIndex: weekIndex, planId: legDay.localId, in: context)
            seedChestCoreDay(at: day(weekStart, 6), weekIndex: weekIndex, planId: pushPull.localId, in: context)
        }

        try context.save()
        return Result(workouts: 24, plans: 2)
    }

    // MARK: - 各训练日

    @MainActor
    private static func seedChestArmsDay(at date: Date, weekIndex: Int, planId: UUID, in context: ModelContext) {
        let workout = beginWorkout(title: "胸 + 手臂", at: date, planId: planId,
                                   note: weekIndex == 5 ? "本周状态不错，卧推加重顺利。" : nil)
        addExercise(benchPress, to: workout, weekIndex: weekIndex, warmup: true,
                    note: weekIndex == 5 ? "顶峰收缩 1 秒" : nil, orderIndex: 0)
        // 每 3 周飞鸟做递减组
        if weekIndex % 3 == 2 {
            addDropSetExercise(fly, to: workout, weekIndex: weekIndex, orderIndex: 1)
        } else {
            addExercise(fly, to: workout, weekIndex: weekIndex, orderIndex: 1)
        }
        // 每 2 周手臂做超级组（弯举 + 下压）
        if weekIndex % 2 == 1 {
            addSuperset(curl, pushdown, to: workout, weekIndex: weekIndex, orderIndex: 2,
                        note: "组间不休息，超级组结束再休")
        } else {
            addExercise(curl, to: workout, weekIndex: weekIndex, orderIndex: 2)
            addExercise(pushdown, to: workout, weekIndex: weekIndex, orderIndex: 3)
        }
        finish(workout, in: context)
    }

    @MainActor
    private static func seedBackShoulderDay(at date: Date, weekIndex: Int, planId: UUID, in context: ModelContext) {
        let workout = beginWorkout(title: "背 + 肩", at: date, planId: planId, note: nil)
        addExercise(pulldown, to: workout, weekIndex: weekIndex, warmup: true, orderIndex: 0)
        addExercise(row, to: workout, weekIndex: weekIndex,
                    note: weekIndex == 4 ? "别耸肩" : nil, orderIndex: 1)
        addExercise(ohp, to: workout, weekIndex: weekIndex, orderIndex: 2)
        finish(workout, in: context)
    }

    @MainActor
    private static func seedLegGluteDay(at date: Date, weekIndex: Int, planId: UUID, in context: ModelContext) {
        let workout = beginWorkout(title: "腿 + 臀", at: date, planId: planId, note: nil)
        addExercise(squat, to: workout, weekIndex: weekIndex, warmup: true, orderIndex: 0)
        addExercise(legPress, to: workout, weekIndex: weekIndex, orderIndex: 1)
        addExercise(rdl, to: workout, weekIndex: weekIndex, orderIndex: 2)
        addExercise(hipThrust, to: workout, weekIndex: weekIndex, orderIndex: 3)
        finish(workout, in: context)
    }

    @MainActor
    private static func seedChestCoreDay(at date: Date, weekIndex: Int, planId: UUID, in context: ModelContext) {
        let workout = beginWorkout(title: "胸 + 核心", at: date, planId: planId, note: nil)
        addExercise(benchPress, to: workout, weekIndex: weekIndex, setsOverride: 3, orderIndex: 0)
        addExercise(crunch, to: workout, weekIndex: weekIndex, orderIndex: 1)
        finish(workout, in: context)
    }

    // MARK: - 构造辅助

    @MainActor
    private static func day(_ weekStart: Date, _ weekdayOffset: Int) -> Date {
        Calendar.currentMondayFirst.date(byAdding: .day, value: weekdayOffset, to: weekStart)?
            .addingTimeInterval(18 * 3600) ?? weekStart   // 固定在 18:00 开练
    }

    @MainActor
    private static func beginWorkout(title: String, at date: Date, planId: UUID, note: String?) -> Workout {
        Workout(planId: planId, title: title, startedAt: date,
                timerStartedAt: date, endedAt: date.addingTimeInterval(55 * 60), note: note)
    }

    @MainActor
    private static func finish(_ workout: Workout, in context: ModelContext) {
        context.insert(workout)
    }

    /// 普通动作：可选 1 组热身 + N 组正式组，主项重量随周渐进。
    @MainActor
    private static func addExercise(_ lift: Lift, to workout: Workout, weekIndex: Int,
                                    warmup: Bool = false, setsOverride: Int? = nil,
                                    note: String? = nil, orderIndex: Int) {
        let exercise = WorkoutExercise(builtinExerciseCode: lift.code,
                                       exerciseName: lift.name,
                                       primaryMuscle: lift.muscle,
                                       orderIndex: orderIndex,
                                       note: note)
        var sets: [WorkoutSet] = []
        if warmup {
            sets.append(WorkoutSet(setIndex: 0, weightKg: lift.baseWeight * 0.5, reps: 12,
                                   completed: true, setType: .warmup))
        }
        let formalCount = setsOverride ?? lift.sets
        let weight = lift.baseWeight + lift.weeklyStep * Double(weekIndex)
        for index in 0..<formalCount {
            sets.append(WorkoutSet(setIndex: sets.count,
                                   weightKg: weight,
                                   reps: lift.reps + (index == formalCount - 1 ? -1 : 0),
                                   completed: true, setType: .working))
        }
        exercise.sets = sets
        workout.exercises.append(exercise)
        workout.appendSingleExerciseUnit(for: exercise)
    }

    /// 递减组动作：3 段 segments 递减。
    @MainActor
    private static func addDropSetExercise(_ lift: Lift, to workout: Workout, weekIndex: Int, orderIndex: Int) {
        let exercise = WorkoutExercise(builtinExerciseCode: lift.code,
                                       exerciseName: lift.name,
                                       primaryMuscle: lift.muscle,
                                       orderIndex: orderIndex)
        let top = lift.baseWeight + lift.weeklyStep * Double(weekIndex)
        exercise.sets = [
            WorkoutSet(setIndex: 0, completed: true, setType: .drop, segments: [
                WorkoutSetSegment(segmentIndex: 0, weightKg: top, reps: 8),
                WorkoutSetSegment(segmentIndex: 1, weightKg: top * 0.8, reps: 8),
                WorkoutSetSegment(segmentIndex: 2, weightKg: top * 0.65, reps: 10)
            ])
        ]
        workout.exercises.append(exercise)
        workout.appendDropSetUnit(for: exercise)
    }

    /// 超级组：两个动作、共享轮数、组间不休息（轮后 90 秒）。
    @MainActor
    private static func addSuperset(_ first: Lift, _ second: Lift, to workout: Workout,
                                    weekIndex: Int, orderIndex: Int, note: String?) {
        let firstExercise = WorkoutExercise(builtinExerciseCode: first.code,
                                            exerciseName: first.name,
                                            primaryMuscle: first.muscle,
                                            orderIndex: orderIndex)
        let secondExercise = WorkoutExercise(builtinExerciseCode: second.code,
                                             exerciseName: second.name,
                                             primaryMuscle: second.muscle,
                                             orderIndex: orderIndex + 1)
        let rounds = 3
        firstExercise.sets = (0..<rounds).map {
            WorkoutSet(setIndex: $0, weightKg: first.baseWeight + first.weeklyStep * Double(weekIndex),
                       reps: first.reps, completed: true, setType: .working)
        }
        secondExercise.sets = (0..<rounds).map {
            WorkoutSet(setIndex: $0, weightKg: second.baseWeight + second.weeklyStep * Double(weekIndex),
                       reps: second.reps, completed: true, setType: .working)
        }
        workout.exercises.append(firstExercise)
        workout.exercises.append(secondExercise)
        workout.appendSupersetUnit(first: firstExercise, second: secondExercise,
                                   roundCount: rounds, restAfterRoundSeconds: 90, note: note)
    }
}
#endif
