import ActivityKit
import Foundation
import os.log

/// 训练会话 Live Activity 控制器。
///
/// 单一职责：把本地 `Workout` 快照转换为 ActivityKit 状态，并在 `workout` / `rest`
/// phase 之间切换。训练记录、休息通知、声音与触觉仍由各自业务模块负责。
@MainActor
@Observable
final class WorkoutLiveActivityController {
    private static let log = Logger(subsystem: "com.yulinxi.app.DontLift", category: "WorkoutLiveActivity")

    private var activity: Activity<RestActivityAttributes>?
    private var currentAttributes: RestActivityAttributes?
    private var currentState: RestActivityAttributes.ContentState?
    private var restReturnTask: Task<Void, Never>?
    private var activityOperationTask: Task<Void, Never>?
    private var activityGeneration = 0

    var currentWorkoutId: UUID? { currentAttributes?.workoutId }

    /// 同步训练会话快照。未开始计时或已结束的会话不会启动 Live Activity。
    func syncWorkout(_ workout: Workout) {
        guard workout.isActive, let startedAt = workout.timerStartedAt else {
            if currentAttributes?.workoutId == workout.localId {
                endWorkout()
            }
            return
        }

        let attributes = RestActivityAttributes(
            workoutId: workout.localId,
            workoutTitle: workout.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "训练",
            startedAt: startedAt
        )
        let workoutState = makeWorkoutState(for: workout)
        let nextState: RestActivityAttributes.ContentState
        let staleDate: Date?

        if let currentState,
           currentState.phase == .rest,
           currentAttributes?.workoutId == workout.localId,
           let restEndDate = currentState.restEndDate,
           restEndDate > .now {
            nextState = RestActivityAttributes.ContentState(
                phase: .rest,
                completedSetCount: workoutState.completedSetCount,
                remainingExerciseCount: workoutState.remainingExerciseCount,
                nextSet: currentState.nextSet ?? workoutState.nextSet,
                restEndDate: currentState.restEndDate,
                restTotalDuration: currentState.restTotalDuration
            )
            staleDate = restEndDate
        } else {
            nextState = workoutState
            staleDate = nil
        }

        upsert(attributes: attributes, state: nextState, staleDate: staleDate)
    }

    /// 进入组间休息 phase。调用方需先通过 `syncWorkout(_:)` 提供当前训练快照。
    func enterRest(endDate: Date,
                   totalDuration: TimeInterval,
                   nextSet: RestActivityAttributes.NextSet?,
                   fallbackExerciseName: String?) {
        guard let attributes = currentAttributes else { return }
        let fallbackNextSet = nextSet ?? fallbackExerciseName.map {
            RestActivityAttributes.NextSet(exerciseName: $0, setIndex: 1, weightText: nil, repsText: nil)
        }
        let base = currentState ?? RestActivityAttributes.ContentState(
            phase: .workout,
            completedSetCount: 0,
            remainingExerciseCount: 0,
            nextSet: fallbackNextSet,
            restEndDate: nil,
            restTotalDuration: nil
        )
        let state = RestActivityAttributes.ContentState(
            phase: .rest,
            completedSetCount: base.completedSetCount,
            remainingExerciseCount: base.remainingExerciseCount,
            nextSet: fallbackNextSet ?? base.nextSet,
            restEndDate: endDate,
            restTotalDuration: totalDuration
        )
        upsert(attributes: attributes, state: state, staleDate: endDate)
        scheduleRestReturn(endDate: endDate)
    }

    /// 休息调时后更新同一个 Activity 的倒计时墙钟。
    func updateRest(endDate: Date, totalDuration: TimeInterval) {
        guard let attributes = currentAttributes,
              let currentState,
              currentState.phase == .rest else { return }
        let state = RestActivityAttributes.ContentState(
            phase: .rest,
            completedSetCount: currentState.completedSetCount,
            remainingExerciseCount: currentState.remainingExerciseCount,
            nextSet: currentState.nextSet,
            restEndDate: endDate,
            restTotalDuration: totalDuration
        )
        upsert(attributes: attributes, state: state, staleDate: endDate)
        scheduleRestReturn(endDate: endDate)
    }

    /// 退出休息 phase，恢复训练正向计时。
    func exitRest() {
        restReturnTask?.cancel()
        restReturnTask = nil
        guard let attributes = currentAttributes,
              let currentState else { return }
        let state = RestActivityAttributes.ContentState(
            phase: .workout,
            completedSetCount: currentState.completedSetCount,
            remainingExerciseCount: currentState.remainingExerciseCount,
            nextSet: currentState.nextSet,
            restEndDate: nil,
            restTotalDuration: nil
        )
        upsert(attributes: attributes, state: state, staleDate: nil)
    }

    /// 结束或放弃训练时立即结束训练会话 Live Activity。
    func endWorkout() {
        restReturnTask?.cancel()
        restReturnTask = nil
        activityGeneration += 1
        activityOperationTask?.cancel()
        activityOperationTask = nil
        currentAttributes = nil
        currentState = nil
        let known = activity
        activity = nil
        Task {
            if let known {
                await known.end(nil, dismissalPolicy: .immediate)
            }
            for act in Activity<RestActivityAttributes>.activities {
                await act.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// App 回前台或根层刷新 active workout 时调用，清理残留或同步最新快照。
    func reconcile(activeWorkout: Workout?) {
        guard let activeWorkout else {
            if activity != nil || !Activity<RestActivityAttributes>.activities.isEmpty {
                endWorkout()
            }
            return
        }
        syncWorkout(activeWorkout)
    }

    private func makeWorkoutState(for workout: Workout) -> RestActivityAttributes.ContentState {
        let completed = workout.completedStatEntryCount
        let remainingExercises = workout.exercises.filter { ex in
            ex.sets.contains { !$0.completed }
        }.count
        return RestActivityAttributes.ContentState(
            phase: .workout,
            completedSetCount: completed,
            remainingExerciseCount: remainingExercises,
            nextSet: nextSetSummary(for: workout),
            restEndDate: nil,
            restTotalDuration: nil
        )
    }

    private func nextSetSummary(for workout: Workout) -> RestActivityAttributes.NextSet? {
        for ex in workout.exercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            if let next = ex.sets.sorted(by: { $0.setIndex < $1.setIndex })
                .first(where: { !$0.completed }) {
                return RestActivityAttributes.NextSet(
                    exerciseName: ex.exerciseName,
                    setIndex: next.setIndex + 1,
                    weightText: next.summaryWeightReps.weightKg.map { "\(formatKg($0)) kg" },
                    repsText: next.summaryWeightReps.reps.map { "\($0) 次" }
                )
            }
        }
        return nil
    }

    private func upsert(attributes: RestActivityAttributes,
                        state: RestActivityAttributes.ContentState,
                        staleDate: Date?) {
        currentAttributes = attributes
        currentState = state
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let generation = activityGeneration
        let previous = activityOperationTask
        activityOperationTask = Task { [weak self, attributes, state, staleDate, previous, generation] in
            await previous?.value
            guard !Task.isCancelled else { return }
            await self?.applyLatestActivityState(attributes: attributes,
                                                state: state,
                                                staleDate: staleDate,
                                                generation: generation)
        }
    }

    private func applyLatestActivityState(attributes: RestActivityAttributes,
                                          state: RestActivityAttributes.ContentState,
                                          staleDate: Date?,
                                          generation: Int) async {
        guard isLatestActivityOperation(attributes: attributes, state: state, generation: generation) else { return }
        let content = ActivityContent(state: state, staleDate: staleDate)

        if activity?.attributes.workoutId != attributes.workoutId {
            activity = Activity<RestActivityAttributes>.activities.first {
                $0.attributes.workoutId == attributes.workoutId
            }
        }

        if let activity, activity.attributes.workoutId == attributes.workoutId {
            await activity.update(content)
            return
        }

        do {
            let act = try Activity.request(attributes: attributes, content: content, pushType: nil)
            guard isLatestActivityOperation(attributes: attributes, state: state, generation: generation) else {
                await act.end(nil, dismissalPolicy: .immediate)
                return
            }
            activity = act
            Self.log.info("训练会话 Live Activity 已启动：\(act.id, privacy: .public)")
        } catch {
            Self.log.error("训练会话 Live Activity 启动失败：\(error.localizedDescription, privacy: .public)")
        }
    }

    private func isLatestActivityOperation(attributes: RestActivityAttributes,
                                           state: RestActivityAttributes.ContentState,
                                           generation: Int) -> Bool {
        guard generation == activityGeneration,
              let currentAttributes,
              currentAttributes.workoutId == attributes.workoutId,
              currentAttributes.workoutTitle == attributes.workoutTitle,
              currentAttributes.startedAt == attributes.startedAt,
              currentState == state else {
            return false
        }
        return true
    }

    private func scheduleRestReturn(endDate: Date) {
        restReturnTask?.cancel()
        restReturnTask = Task { [weak self] in
            let delay = max(0, endDate.timeIntervalSinceNow)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self?.currentState?.phase == .rest,
                      self?.currentState?.restEndDate == endDate else { return }
                self?.exitRest()
            }
        }
    }
}
