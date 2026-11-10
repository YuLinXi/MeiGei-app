#if DEBUG
import Foundation
import SwiftData

extension UITestHooks {
    static var isFinishFlowUITest: Bool {
        isAutoLogin && isLiveWorkoutUITest && ProcessInfo.processInfo.arguments.contains("-uitest-finish-flow")
    }

    /// 仅在本场景的全新内存库播种：同次实际完成命中回写、卧推 PR 与累计 10 吨徽章。
    @MainActor static func seedFinishFlow(in context: ModelContext) {
        if ProcessInfo.processInfo.arguments.contains("-uitest-long-poster") {
            seedLongPoster(in: context)
            return
        }
        let mode: WorkoutPlanMode = ProcessInfo.processInfo.arguments.contains("-uitest-finish-strict") ? .strict : .adaptive
        let item = PlanItem(builtinExerciseCode: "BB_BENCH_PRESS", exerciseName: "杠铃卧推", orderIndex: 0,
                            suggestedSets: 15, suggestedReps: 8, suggestedWeightKg: 60)
        let plan = WorkoutPlan(name: mode == .strict ? "UI 收尾严格计划" : "UI 收尾自适应计划", items: [item], mode: mode)
        context.insert(plan)
        let past = Date.now.addingTimeInterval(-86_400)
        context.insert(Workout(title: "UI 收尾历史基线", startedAt: past, timerStartedAt: past,
                               endedAt: past.addingTimeInterval(1800), exercises: [
            WorkoutExercise(builtinExerciseCode: "BB_BENCH_PRESS", exerciseName: "杠铃卧推", orderIndex: 0,
                            sets: [WorkoutSet(setIndex: 0, weightKg: 40, reps: 8, completed: true)])
        ]))
        let exercise = WorkoutExercise(builtinExerciseCode: "BB_BENCH_PRESS", exerciseName: "杠铃卧推", orderIndex: 0,
                                       planItemId: item.itemId,
                                       sets: (0..<15).map { WorkoutSet(setIndex: $0, weightKg: 80, reps: 10, completed: true) })
        let workout = Workout(planId: plan.localId, title: "UI 收尾多结果",
                              startedAt: .now.addingTimeInterval(-3600), timerStartedAt: .now.addingTimeInterval(-3600),
                              exercises: [exercise])
        context.insert(workout)
        try? LocalModelSave.save(context)
    }

    /// 长训练导出使用独立内存样例，不改变既有性能矩阵的数据结构。
    @MainActor private static func seedLongPoster(in context: ModelContext) {
        let end = Date.now
        let start = end.addingTimeInterval(-3600)
        let exercises = (0..<20).map { index in
            let custom = CustomExercise(name: String(format: "UI 海报动作 %02d", index + 1))
            context.insert(custom)
            return WorkoutExercise(customExerciseId: custom.localId, exerciseName: custom.name, orderIndex: index,
                                   sets: (0..<5).map { WorkoutSet(setIndex: $0, weightKg: 60, reps: 10, completed: true) })
        }
        context.insert(Workout(title: "UI 长训练海报", startedAt: start, timerStartedAt: start,
                               endedAt: end, exercises: exercises))
        try? LocalModelSave.save(context)
    }
}
#endif
