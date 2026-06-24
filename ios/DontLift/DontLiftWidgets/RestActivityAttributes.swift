import ActivityKit
import Foundation

/// 组间休息 Live Activity 的属性。app 与 widget extension **共用同一份源码**，
/// ActivityKit 按类型名跨进程匹配，故两端各编译一份是标准做法。
struct RestActivityAttributes: ActivityAttributes {
    struct NextSet: Codable, Hashable {
        /// 下一组所属动作名。
        var exerciseName: String
        /// 面向用户展示的组序号（1-based）。
        var setIndex: Int
        /// 下一组重量文案，已在主 App 侧按本地口径格式化，例如 "80 kg"。
        var weightText: String?
        /// 下一组次数文案，例如 "10 次"。
        var repsText: String?

        var setLabel: String { "第 \(setIndex) 组" }
    }

    struct ContentState: Codable, Hashable {
        /// 本次休息结束时刻（墙钟）。Live Activity 用 `Text(timerInterval:)` 自走倒计时，
        /// 无需频繁推送更新——这正是「锁屏/后台持续显示剩余秒数」的实现方式。
        var endDate: Date
        /// 休息结束后要练的下一个动作名。
        var nextExercise: String?
        /// 下一组结构化信息，用于灵动岛 expanded 与锁屏卡片展示重量/次数。
        var nextSet: NextSet?
    }

    /// 启动时固定的本次休息总时长（秒）。
    var totalDuration: Double
}
