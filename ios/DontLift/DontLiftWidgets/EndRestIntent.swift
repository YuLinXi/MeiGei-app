import ActivityKit
import AppIntents
import Foundation

/// 「提前结束休息」App Intent：从 Live Activity（锁屏/灵动岛/配对 Watch Smart Stack）按钮触发。
/// 在 widget 进程里直接结束所有休息 Live Activity，并发 Darwin 通知让主 App 同步清理本地计时与待发提醒。
struct EndRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "提前结束休息"
    static var description = IntentDescription("结束当前组间休息并进入下一组")

    func perform() async throws -> some IntentResult {
        for activity in Activity<RestActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
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
