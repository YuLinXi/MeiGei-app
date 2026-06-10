import ActivityKit
import Foundation

/// 组间休息 Live Activity 的属性。app 与 widget extension **共用同一份源码**，
/// ActivityKit 按类型名跨进程匹配，故两端各编译一份是标准做法。
struct RestActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// 本次休息结束时刻（墙钟）。Live Activity 用 `Text(timerInterval:)` 自走倒计时，
        /// 无需频繁推送更新——这正是「锁屏/后台持续显示剩余秒数」的实现方式。
        var endDate: Date
        /// 休息结束后要练的下一个动作名。
        var nextExercise: String?
    }

    /// 启动时固定的本次休息总时长（秒）。
    var totalDuration: Double
}
