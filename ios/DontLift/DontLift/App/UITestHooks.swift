#if DEBUG
import Foundation
import SwiftData

/// UI 测试与开发调试钩子：仅 DEBUG 且携带启动参数时生效。
enum UITestHooks {
    static let liveWorkoutArg = "-uitest-live-workout"
    static let autoReorderArg = "-uitest-auto-reorder"
    static let autoLoginArg = "-dev-auto-login"
    static let seedDemoArg = "-dev-seed-demo"
    static let historySaveArg = "-uitest-history-save"

    static var isLiveWorkoutUITest: Bool {
        ProcessInfo.processInfo.arguments.contains(liveWorkoutArg)
    }

    static var isAutoReorderUITest: Bool {
        isLiveWorkoutUITest && ProcessInfo.processInfo.arguments.contains(autoReorderArg)
    }

    static var isAutoLogin: Bool {
        ProcessInfo.processInfo.arguments.contains(autoLoginArg)
    }

    static var isSeedDemoData: Bool {
        ProcessInfo.processInfo.arguments.contains(seedDemoArg)
    }

    /// 历史另存 UI 用例：必须与 `-dev-auto-login` 同用，才落到独立 `WorkoutUITests.store` 并跳过同步。
    static var isHistorySaveUITest: Bool {
        isAutoLogin && ProcessInfo.processInfo.arguments.contains(historySaveArg)
    }

    static let historySaveSamplePrefix = "UI 另存"

    /// 「历史训练另存为个人计划」UI 用例样例。
    ///
    /// 用途：首页「本周训练」与历史日历当天各有一条可另存训练（来源个人计划已不存在，含逐组不同正式组）
    /// 和一条只有热身组、不可另存的训练，外加一个空计划分组供保存时选择。
    /// 隔离边界：仅在 `isHistorySaveUITest`（DEBUG + `-dev-auto-login`）下运行，写入的是
    /// `AppModelContainer` 为假登录选择的独立 `WorkoutUITests.store`；假登录跳过同步，样例不会上传。
    /// 每次启动先清理带 `historySaveSamplePrefix` 前缀的旧训练／计划／分组，保证用例可重复。
    @MainActor
    static func seedHistorySaveSamplesIfNeeded(container: ModelContainer) {
        guard isHistorySaveUITest else { return }
        let context = container.mainContext
        let prefix = historySaveSamplePrefix
        for workout in (try? context.fetch(FetchDescriptor<Workout>())) ?? [] {
            if (workout.title ?? "").hasPrefix(prefix) {
                context.delete(workout)
            } else if workout.endedAt == nil && workout.deletedAt == nil {
                workout.endedAt = .now
            }
        }
        for plan in (try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? [] where plan.name.hasPrefix(prefix) {
            context.delete(plan)
        }
        for group in (try? context.fetch(FetchDescriptor<WorkoutPlanGroup>())) ?? [] where group.name.hasPrefix(prefix) {
            context.delete(group)
        }
        try? context.save()

        let now = Date.now
        context.insert(WorkoutPlanGroup(name: "\(prefix)分组", sortOrder: 9_999))
        let bench = WorkoutExercise(builtinExerciseCode: "BB_BENCH_PRESS", exerciseName: "杠铃卧推", orderIndex: 0,
                                    sets: [
                                        WorkoutSet(setIndex: 0, weightKg: 60, reps: 10, completed: true),
                                        WorkoutSet(setIndex: 1, weightKg: 65, reps: 8, completed: true),
                                        WorkoutSet(setIndex: 2, weightKg: 70, reps: 6, completed: true)
                                    ])
        let start = now.addingTimeInterval(-40 * 60)
        context.insert(Workout(planId: UUID(), title: "\(prefix)胸背", startedAt: start, timerStartedAt: start,
                               endedAt: now.addingTimeInterval(-60), note: "\(prefix)备注", exercises: [bench]))
        let warmup = WorkoutExercise(builtinExerciseCode: "BB_BENCH_PRESS", exerciseName: "杠铃卧推", orderIndex: 0,
                                     sets: [WorkoutSet(setIndex: 0, weightKg: 20, reps: 10, completed: true,
                                                       setType: .warmup)])
        let warmStart = now.addingTimeInterval(-120 * 60)
        context.insert(Workout(title: "\(prefix)热身", startedAt: warmStart, timerStartedAt: warmStart,
                               endedAt: warmStart.addingTimeInterval(600), exercises: [warmup]))
        try? context.save()
    }

    /// 模拟另存表单打开后，原训练被同步软删；仅操作隔离测试库中的历史样例。
    @MainActor
    static func invalidateHistorySaveSourceIfNeeded(_ workout: Workout, context: ModelContext) {
        guard isHistorySaveUITest,
              ProcessInfo.processInfo.arguments.contains("-uitest-history-save-invalid-source"),
              (workout.title ?? "").hasPrefix(historySaveSamplePrefix),
              workout.deletedAt == nil else { return }
        workout.markDeleted()
        try? context.save()
    }

    /// 在 App 启动装配期调用：播种进行中训练。确保每次启动具有确定性的干净动作列表。
    @MainActor
    static func seedLiveWorkoutIfNeeded(container: ModelContainer) {
        guard isLiveWorkoutUITest else { return }
        let context = container.mainContext
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-profile-workout"), let index = args.firstIndex(of: "-profile-history-count"), index + 1 < args.count,
           let count = Int(args[index + 1]), count >= 0 {
            // AppModelContainer 已选择独立性能测试库，不触碰日常训练库。
            let existing = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
            for workout in existing { context.delete(workout) }
            try? context.save()
            for i in 0..<count {
                let start = Date.now.addingTimeInterval(-Double(i + 1) * 86400)
                let exercises = (0..<6).map { j in
                    WorkoutExercise(builtinExerciseCode: "BB_BENCH_PRESS", exerciseName: "杠铃卧推", orderIndex: j,
                                    sets: (0..<4).map { WorkoutSet(setIndex: $0, weightKg: 60, reps: 10, completed: true) })
                }
                context.insert(Workout(title: "性能测试历史 \(i)", startedAt: start,
                                       timerStartedAt: start, endedAt: start.addingTimeInterval(3600), exercises: exercises))
            }
            try? context.save()
        }
        if args.contains("-profile-workout"), args.contains("-profile-resume-workout"),
           WorkoutSession.activeSession(in: context) != nil { return }
        let isLong = args.contains("-profile-long-workout")
        let isAssisted = ProcessInfo.processInfo.arguments.contains("-uitest-assisted-weight")
        let allWorkouts = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
        for workout in allWorkouts {
            if workout.title == "UI 测试训练" {
                context.delete(workout)
            } else if workout.endedAt == nil && workout.deletedAt == nil {
                workout.endedAt = .now
            }
        }
        try? context.save()

        let exercises = liveWorkoutExercises(isLong: isLong)
        if isAssisted, let first = exercises.first {
            first.builtinExerciseCode = "ASSISTED_PULL_UP"
            first.exerciseName = "辅助引体向上"
        }
        let workout = Workout(title: "UI 测试训练",
                              startedAt: .now,
                              timerStartedAt: .now,
                              exercises: exercises)
        context.insert(workout)
        try? context.save()
    }

    @MainActor
    static func liveWorkoutExercises(isLong: Bool) -> [WorkoutExercise] {
        let names = isLong ? (0..<20).map { "测试动作 \($0 + 1)" } : ["上斜杠铃卧推", "杠铃划船", "哑铃肩推"]
        let codes = ["INCLINE_BB_PRESS", "BB_ROW", "DB_SHOULDER_PRESS"]
        return names.enumerated().map { index, name in
            WorkoutExercise(builtinExerciseCode: codes[index % codes.count], exerciseName: name,
                            orderIndex: index,
                            sets: (0..<(isLong ? 5 : 3)).map { WorkoutSet(setIndex: $0, weightKg: 60, reps: 10) })
        }
    }

    /// 在 App 启动装配期调用：播种演示数据并执行勋章回溯。
    @MainActor
    static func seedDemoDataAndBadges(in context: ModelContext) {
        WorkoutCaloriePreferences.setBodyWeightKg(75.0)
        _ = try? WorkoutDemoSeedData.seed(in: context)
        UserDefaults.standard.removeObject(forKey: BadgeEngine.backfillCompletedKey)
        UserDefaults.standard.removeObject(forKey: BadgeEngine.careerReviewShownKey)
        configureLaunchEnvironment()
    }

    /// 在 App 启动装配期调用：清除进行中训练会话（用于测试主页/生涯回顾等正常展示）。
    @MainActor
    static func clearActiveWorkoutIfNeeded(container: ModelContainer) {
        if ProcessInfo.processInfo.arguments.contains("-clear-active-workout") {
            let context = container.mainContext
            let active = WorkoutSession.activeSession(in: context)
            if let active {
                active.endedAt = .now
                try? context.save()
            }
        }
    }

    /// 在 App 启动装配期调用：配置环境标志。
    static func configureLaunchEnvironment() {
        if ProcessInfo.processInfo.arguments.contains("-dismiss-career-review") {
            UserDefaults.standard.set(true, forKey: BadgeEngine.careerReviewShownKey)
        }
    }

    static var testBadgeDetailId: String? {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-test-badge-detail"), idx + 1 < args.count {
            return args[idx + 1]
        }
        return nil
    }

    static var isTestBadgeCelebration: Bool {
        ProcessInfo.processInfo.arguments.contains("-test-badge-celebration")
    }
}
#endif
