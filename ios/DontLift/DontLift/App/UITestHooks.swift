#if DEBUG
import Foundation
import SwiftData
import UIKit

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

    static var textSizeOverride: UIContentSizeCategory? {
        guard isAutoLogin || isLiveWorkoutUITest else { return nil }
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-uitest-typography-size"), index + 1 < args.count else { return nil }
        switch args[index + 1] {
        case "large": return .large
        case "xxxLarge": return .extraExtraExtraLarge
        case "accessibility5": return .accessibilityExtraExtraExtraLarge
        default: return nil
        }
    }

    @MainActor static func applyTypographyTraits() {
        guard let category = textSizeOverride else { return }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.traitOverrides.preferredContentSizeCategory = category
        }
    }

    static var isProfileRecoveryUITest: Bool {
        isAutoLogin && ProcessInfo.processInfo.arguments.contains("-uitest-profile-recovery")
    }

    static var isProfileCompletionUITest: Bool {
        isAutoLogin && ProcessInfo.processInfo.arguments.contains("-uitest-profile-completion")
    }

    static var isLocalCleanupRecoveryUITest: Bool {
        isAutoLogin && ProcessInfo.processInfo.arguments.contains("-uitest-local-cleanup-recovery")
    }

    @MainActor private static var profileRecoveryAttempts = 0
    @MainActor private static var injectedSaveFailures: Set<String> = []
    @MainActor private static var presentedWritebackRecovery = false

    @MainActor static func presentWritebackRecoveryIfNeeded(in context: ModelContext, center: PlanWritebackCenter) {
        guard isAutoLogin, ProcessInfo.processInfo.arguments.contains("-uitest-writeback-recovery"),
              !presentedWritebackRecovery else { return }
        presentedWritebackRecovery = true
        let name = "UI 回写恢复计划"
        for plan in (try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? [] where plan.name == name {
            context.delete(plan)
        }
        let original = PlanItem(exerciseName: "杠铃卧推", orderIndex: 0, suggestedSets: 3, suggestedReps: 8, suggestedWeightKg: 60)
        var revised = original
        revised.suggestedWeightKg = 65
        let plan = WorkoutPlan(name: name, items: [revised])
        context.insert(plan)
        try? LocalModelSave.save(context)
        center.present(.init(planLocalId: plan.localId, planName: name, diffs: [
            .init(kind: .updated, exerciseName: original.exerciseName, oldText: "3 × 8 × 60kg", newText: "3 × 8 × 65kg")
        ], snapshot: [original]))
    }

    /// 每次进程只失败一次，且只在隔离 UI 测试库中启用；重试走真实 LocalModelSave.save(context)。
    @MainActor static func failFirstSaveIfNeeded(_ kind: String) throws {
        guard isAutoLogin || isLiveWorkoutUITest,
              ProcessInfo.processInfo.arguments.contains("-uitest-fail-\(kind)-save"),
              injectedSaveFailures.insert(kind).inserted else { return }
        throw CocoaError(.fileWriteNoPermission)
    }

    @MainActor static func seedPlanSaveRecoveryIfNeeded(container: ModelContainer) {
        let args = ProcessInfo.processInfo.arguments
        guard isAutoLogin, args.contains("-uitest-fail-plan-save") || args.contains("-uitest-fail-commit-save") else { return }
        let context = container.mainContext
        let prefix = "UI 保存计划"
        for plan in (try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? [] where plan.name.hasPrefix(prefix) {
            context.delete(plan)
        }
        context.insert(WorkoutPlan(name: prefix, items: [
            PlanItem(exerciseName: "杠铃卧推", orderIndex: 0, suggestedSets: 3,
                     suggestedReps: 8, suggestedWeightKg: 60)
        ]))
        let groupName = "UI 保存目标分组"
        for group in (try? context.fetch(FetchDescriptor<WorkoutPlanGroup>())) ?? [] where group.name.hasPrefix("UI 保存") {
            context.delete(group)
        }
        context.insert(WorkoutPlanGroup(name: groupName, sortOrder: 99_999))
        try? LocalModelSave.save(context)
    }

    /// 只在假登录的独立测试库内创建长名称与三类训练单元。
    @MainActor static func seedPlanReadabilityIfNeeded(container: ModelContainer) {
        guard isAutoLogin, ProcessInfo.processInfo.arguments.contains("-uitest-plan-readability") else { return }
        let context = container.mainContext
        let prefix = "UI 大字"
        for plan in (try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? [] where plan.name.hasPrefix(prefix) {
            context.delete(plan)
        }
        for group in (try? context.fetch(FetchDescriptor<WorkoutPlanGroup>())) ?? [] where group.name.hasPrefix(prefix) {
            context.delete(group)
        }
        for exercise in (try? context.fetch(FetchDescriptor<CustomExercise>())) ?? [] where exercise.name.hasPrefix(prefix) {
            context.delete(exercise)
        }
        let exercise = CustomExercise(name: "UI 大字坐姿器械胸部推举与稳定控制训练", primaryMuscle: "胸", equipmentType: "器械")
        context.insert(exercise)
        let group = WorkoutPlanGroup(name: "UI 大字分组 · 长期力量与稳定控制", sortOrder: -99_999)
        context.insert(group)
        var items: [PlanItem] = [
            PlanItem(customExerciseId: exercise.localId, exerciseName: exercise.name, orderIndex: 0,
                     suggestedSets: 3, suggestedReps: 8, suggestedWeightKg: 60),
            .dropSet(orderIndex: 1, builtinExerciseCode: "BB_BENCH_PRESS", exerciseName: "杠铃卧推", groupCount: 2,
                     segments: [WorkoutSetSegment(segmentIndex: 0, weightKg: 80, reps: 8),
                                WorkoutSetSegment(segmentIndex: 1, weightKg: 60, reps: 6),
                                WorkoutSetSegment(segmentIndex: 2, weightKg: 45, reps: 9)]),
            .superset(orderIndex: 2, roundCount: 3, restAfterRoundSeconds: 90, members: [
                PlanSupersetMember(builtinExerciseCode: "BB_ROW", exerciseName: "杠铃划船", orderIndex: 0,
                                   suggestedWeightKg: 50, suggestedReps: 10),
                PlanSupersetMember(builtinExerciseCode: "DB_SHOULDER_PRESS", exerciseName: "坐姿哑铃推肩", orderIndex: 1,
                                   suggestedWeightKg: 15, suggestedReps: 12)
            ])
        ]
        if ProcessInfo.processInfo.arguments.contains("-uitest-plan-alternatives") {
            items[0].alternatives = [PlanExerciseOption(builtinExerciseCode: "DB_BENCH_PRESS", exerciseName: "哑铃卧推")]
        }
        let plan = WorkoutPlan(name: "UI 大字计划 · 胸背力量与训练复盘", items: items)
        plan.groupId = group.localId
        plan.note = "保留实际训练安排，逐组核对重量和次数。"
        context.insert(plan)
        if ProcessInfo.processInfo.arguments.contains("-uitest-reorder-draft") {
            context.insert(WorkoutPlanGroup(name: "UI 大字分组 · 排序对照", sortOrder: -99_998))
            context.insert(WorkoutPlan(name: "UI 大字计划 · 排序对照", items: items,
                                       groupId: group.localId, sortOrder: 1))
        }
        try? LocalModelSave.save(context)
    }

    @MainActor static func profileRecoveryResponse() throws -> ProfileDTO {
        if isProfileCompletionUITest {
            return ProfileDTO(userId: UUID(), displayName: nil, sex: nil, email: nil)
        }
        profileRecoveryAttempts += 1
        guard ProcessInfo.processInfo.arguments.contains("-uitest-profile-recovery-success"),
              profileRecoveryAttempts > 5 else { throw URLError(.notConnectedToInternet) }
        return ProfileDTO(userId: UUID(), displayName: "恢复测试用户", sex: "male", email: nil)
    }

    static func profileUpdateResponse(_ patch: ProfilePatchRequest) -> ProfileDTO {
        ProfileDTO(userId: UUID(), displayName: patch.displayName, sex: patch.sex, email: nil)
    }

    @MainActor static func profileCompletionResponse(_ patch: ProfilePatchRequest) throws -> ProfileDTO {
        if isProfileCompletionUITest, injectedSaveFailures.insert("completion-response").inserted {
            throw URLError(.notConnectedToInternet)
        }
        return profileUpdateResponse(patch)
    }

    /// 仅在独立 UI 测试库提供可反查的徽章与训练，不设置日常体重或重置偏好。
    @MainActor static func seedBadgeReadabilityIfNeeded(container: ModelContainer) {
        guard isAutoLogin, ProcessInfo.processInfo.arguments.contains("-uitest-badge-readability") else { return }
        let context = container.mainContext
        let title = "UI 大字徽章训练"
        let descriptor = FetchDescriptor<Workout>(predicate: #Predicate { $0.title == title })
        if (try? context.fetch(descriptor).first) == nil {
            let exercise = WorkoutExercise(builtinExerciseCode: "BB_BENCH_PRESS", exerciseName: "杠铃卧推", orderIndex: 0,
                                           sets: [WorkoutSet(setIndex: 0, weightKg: 60, reps: 8, completed: true)])
            let workout = Workout(title: title, startedAt: .now.addingTimeInterval(-3600), endedAt: .now, exercises: [exercise])
            context.insert(workout)
        }
        try? LocalModelSave.save(context)
    }

    /// 只在独立 WorkoutUITests.store 中提供恢复后可见的记录，不修改日常训练库。
    @MainActor static func seedProfileRecoveryIfNeeded(container: ModelContainer) {
        guard isProfileRecoveryUITest else { return }
        let context = container.mainContext
        let title = "UI 恢复保留训练"
        let descriptor = FetchDescriptor<Workout>(predicate: #Predicate { $0.title == title })
        let workout = (try? context.fetch(descriptor).first) ?? Workout(title: title)
        if workout.modelContext == nil { context.insert(workout) }
        workout.startedAt = .now.addingTimeInterval(-3600)
        workout.endedAt = .now
        try? LocalModelSave.save(context)
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
        try? LocalModelSave.save(context)

        let now = Date.now
        let today = Calendar.current.startOfDay(for: now)
        context.insert(WorkoutPlanGroup(name: "\(prefix)分组", sortOrder: 9_999))
        let bench = WorkoutExercise(builtinExerciseCode: "BB_BENCH_PRESS", exerciseName: "杠铃卧推", orderIndex: 0,
                                    sets: [
                                        WorkoutSet(setIndex: 0, weightKg: 60, reps: 10, completed: true),
                                        WorkoutSet(setIndex: 1, weightKg: 65, reps: 8, completed: true),
                                        WorkoutSet(setIndex: 2, weightKg: 70, reps: 6, completed: true)
                                    ])
        let start = max(today, now.addingTimeInterval(-40 * 60))
        context.insert(Workout(planId: UUID(), title: "\(prefix)胸背", startedAt: start, timerStartedAt: start,
                               endedAt: max(start, now.addingTimeInterval(-60)), note: "\(prefix)备注", exercises: [bench]))
        let warmup = WorkoutExercise(builtinExerciseCode: "BB_BENCH_PRESS", exerciseName: "杠铃卧推", orderIndex: 0,
                                     sets: [WorkoutSet(setIndex: 0, weightKg: 20, reps: 10, completed: true,
                                                       setType: .warmup)])
        let warmStart = max(today, now.addingTimeInterval(-120 * 60))
        context.insert(Workout(title: "\(prefix)热身", startedAt: warmStart, timerStartedAt: warmStart,
                               endedAt: min(now, warmStart.addingTimeInterval(600)), exercises: [warmup]))
        try? LocalModelSave.save(context)
    }

    /// 模拟另存表单打开后，原训练被同步软删；仅操作隔离测试库中的历史样例。
    @MainActor
    static func invalidateHistorySaveSourceIfNeeded(_ workout: Workout, context: ModelContext) {
        guard isHistorySaveUITest,
              ProcessInfo.processInfo.arguments.contains("-uitest-history-save-invalid-source"),
              (workout.title ?? "").hasPrefix(historySaveSamplePrefix),
              workout.deletedAt == nil else { return }
        workout.markDeleted()
        try? LocalModelSave.save(context)
    }

    /// 在 App 启动装配期调用：播种进行中训练。确保每次启动具有确定性的干净动作列表。
    @MainActor
    static func seedLiveWorkoutIfNeeded(container: ModelContainer) {
        guard isLiveWorkoutUITest else { return }
        if isFinishFlowUITest {
            seedFinishFlow(in: container.mainContext)
            return
        }
        let context = container.mainContext
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-profile-workout"), let index = args.firstIndex(of: "-profile-history-count"), index + 1 < args.count,
           let count = Int(args[index + 1]), count >= 0 {
            // AppModelContainer 已选择独立性能测试库，不触碰日常训练库。
            let existing = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
            for workout in existing { context.delete(workout) }
            try? LocalModelSave.save(context)
            for i in 0..<count {
                let start = Date.now.addingTimeInterval(-Double(i + 1) * 86400)
                let exercises = (0..<6).map { j in
                    WorkoutExercise(builtinExerciseCode: "BB_BENCH_PRESS", exerciseName: "杠铃卧推", orderIndex: j,
                                    sets: (0..<4).map { WorkoutSet(setIndex: $0, weightKg: 60, reps: 10, completed: true) })
                }
                context.insert(Workout(title: "性能测试历史 \(i)", startedAt: start,
                                       timerStartedAt: start, endedAt: start.addingTimeInterval(3600), exercises: exercises))
            }
            try? LocalModelSave.save(context)
        }
        if args.contains("-profile-workout"), let index = args.firstIndex(of: "-profile-plan-count"), index + 1 < args.count,
           let count = Int(args[index + 1]), count >= 0 {
            // 与历史规模样本共用独立性能库；长处方与大分组不写入日常库。
            for plan in (try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? [] { context.delete(plan) }
            for group in (try? context.fetch(FetchDescriptor<WorkoutPlanGroup>())) ?? [] { context.delete(group) }
            if count > 0 {
                let group = WorkoutPlanGroup(name: "性能计划分组", sortOrder: 0)
                context.insert(group)
                context.insert(WorkoutPlanGroup(name: "性能空分组", sortOrder: 1))
                for planIndex in 0..<count {
                    let isLong = planIndex == 0
                    let items: [PlanItem] = (0..<(isLong ? 20 : 6)).map { exerciseIndex in
                        let prescriptions = (0..<(isLong ? 5 : 3)).map { setIndex in
                            PlanSetPrescription(orderIndex: setIndex, weightKg: 60 - Double(setIndex) * 2.5,
                                                reps: 10 - setIndex)
                        }
                        return PlanItem(builtinExerciseCode: "BB_BENCH_PRESS", exerciseName: "杠铃卧推",
                                        orderIndex: exerciseIndex, setPrescriptions: prescriptions)
                    }
                    context.insert(WorkoutPlan(name: String(format: "性能个人计划 %03d · 胸背力量与训练复盘", planIndex),
                                               items: items, groupId: group.localId, sortOrder: planIndex))
                }
            }
            try? LocalModelSave.save(context)
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
        try? LocalModelSave.save(context)

        let exercises = liveWorkoutExercises(isLong: isLong)
        if isAssisted, let first = exercises.first {
            first.builtinExerciseCode = "ASSISTED_PULL_UP"
            first.exerciseName = "辅助引体向上"
        }
        let workout = Workout(title: "UI 测试训练",
                              startedAt: .now,
                              timerStartedAt: .now,
                              exercises: exercises)
        if args.contains("-uitest-typography-size") {
            workout.storedUnits = exercises.enumerated().map { index, exercise in
                WorkoutUnit(kind: .singleExercise, orderIndex: index,
                            singleExerciseId: exercise.localId, restAfterSetSeconds: 300)
            }
        }
        if args.contains("-uitest-structured-workout") {
            exercises[0].sets = [WorkoutSet(setIndex: 0, setType: .drop, segments: [
                WorkoutSetSegment(segmentIndex: 0, weightKg: 80, reps: 8),
                WorkoutSetSegment(segmentIndex: 1, weightKg: 60, reps: 6),
                WorkoutSetSegment(segmentIndex: 2, weightKg: 45, reps: 8)
            ])]
            workout.storedUnits = [
                WorkoutUnit(kind: .dropSet, orderIndex: 0, singleExerciseId: exercises[0].localId,
                            restAfterSetSeconds: 300),
                WorkoutUnit(kind: .superset, orderIndex: 1, superset: WorkoutSupersetUnit(
                    roundCount: 3, restAfterRoundSeconds: 300, members: [
                        WorkoutSupersetMember(exerciseId: exercises[1].localId, orderIndex: 0),
                        WorkoutSupersetMember(exerciseId: exercises[2].localId, orderIndex: 1)
                    ]))
            ]
        }
        context.insert(workout)
        try? LocalModelSave.save(context)
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
                try? LocalModelSave.save(context)
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
