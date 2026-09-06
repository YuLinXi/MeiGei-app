#if DEBUG
import Foundation
import SwiftData

/// UI 测试与开发调试钩子：仅 DEBUG 且携带启动参数时生效。
enum UITestHooks {
    static let liveWorkoutArg = "-uitest-live-workout"
    static let autoReorderArg = "-uitest-auto-reorder"
    static let autoLoginArg = "-dev-auto-login"
    static let seedDemoArg = "-dev-seed-demo"

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

    /// 在 App 启动装配期调用：播种进行中训练。确保每次启动具有确定性的干净动作列表。
    @MainActor
    static func seedLiveWorkoutIfNeeded(container: ModelContainer) {
        guard isLiveWorkoutUITest else { return }
        let context = container.mainContext
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

        let exercises = ["上斜杠铃卧推", "杠铃划船", "哑铃肩推"].enumerated().map { index, name in
            WorkoutExercise(exerciseName: name,
                            orderIndex: index,
                            sets: (0..<3).map { WorkoutSet(setIndex: $0, weightKg: 60, reps: 10) })
        }
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
