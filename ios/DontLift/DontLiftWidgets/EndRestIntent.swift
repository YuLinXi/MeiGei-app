import ActivityKit
import AppIntents
import Foundation

/// 「提前结束休息」App Intent：从 Live Activity（锁屏/灵动岛；平台支持时也可能来自 Watch Smart Stack）按钮触发。
/// 只结束当前休息 phase，并通过 Darwin 通知让主 App 同步清理本地计时与待发提醒；
/// 不结束或归档整场训练。
struct EndRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "提前结束休息"
    static var description = IntentDescription("结束当前组间休息并进入下一组")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        for activity in Activity<RestActivityAttributes>.activities where activity.content.state.phase == .rest {
            let current = activity.content.state
            let state = RestActivityAttributes.ContentState(
                phase: .workout,
                completedSetCount: current.completedSetCount,
                remainingExerciseCount: current.remainingExerciseCount,
                nextSet: current.nextSet,
                restEndDate: nil,
                restTotalDuration: nil
            )
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
        RestSignal.postEndRest()
        return .result()
    }
}

/// 跨进程信号：widget 里的 App Intent 通知主 App「休息已被提前结束」。
/// 用 Darwin 通知（无需 App Group 实体容器）；主 App 收到后清理 RestTimerController 状态与本地通知。
enum RestSignal {
    static let endRestName = "com.yulinxi.app.DontLift.endRest"

    static func postEndRest() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(endRestName as CFString),
            nil, nil, true)
    }
}
