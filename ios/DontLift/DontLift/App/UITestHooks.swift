#if DEBUG
import Foundation
import SwiftData

/// UI 测试钩子：仅 DEBUG 且携带启动参数时生效，让 XCUITest / simctl 手动启动直达「训练进行中」页面。
///
/// - `-uitest-live-workout`：注入内存假登录态（无签名模拟器 build 写 Keychain 会 -34018，故走内存注入）
///   + 本地画像（含称呼，直接置位补全门控）+ 一条进行中训练（3 动作 × 3 组），
///   MainTabView 出现时自动展开训练浮层。
/// - `-uitest-auto-reorder`：在上述基础上，训练浮层出现后自动进入动作排序模式（供截图验证蒙层）。
enum UITestHooks {
    static let liveWorkoutArg = "-uitest-live-workout"
    static let autoReorderArg = "-uitest-auto-reorder"

    static var isLiveWorkoutUITest: Bool {
        ProcessInfo.processInfo.arguments.contains(liveWorkoutArg)
    }

    static var isAutoReorderUITest: Bool {
        isLiveWorkoutUITest && ProcessInfo.processInfo.arguments.contains(autoReorderArg)
    }

    /// 在 App 启动装配期调用：播种进行中训练。幂等：已存在进行中会话则跳过（重启场景）。
    @MainActor
    static func seedLiveWorkoutIfNeeded(container: ModelContainer) {
        guard isLiveWorkoutUITest else { return }
        let context = container.mainContext
        guard WorkoutSession.activeSession(in: context) == nil else { return }
        let exercises = ["上斜杠铃卧推", "杠铃划船", "哑铃肩推"].enumerated().map { index, name in
            WorkoutExercise(exerciseName: name,
                            orderIndex: index,
                            sets: (0..<3).map { WorkoutSet(setIndex: $0, weightKg: 60, reps: 10) })
        }
        let workout = Workout(title: "UI 测试训练",
                              startedAt: .now,
                              timerStartedAt: .now,
                              exercises: exercises)
        context.insert(workout)
        try? context.save()
    }
}
#endif
