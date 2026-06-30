import ActivityKit
import Foundation

/// 训练会话 Live Activity 的属性。app 与 widget extension **共用同一份源码**，
/// ActivityKit 按类型名跨进程匹配，故两端各编译一份是标准做法。
///
/// 类型名沿用 `RestActivityAttributes`，避免改动既有 Xcode target membership；
/// 语义已升级为训练会话，`rest` 只是其中一个 phase。
struct RestActivityAttributes: ActivityAttributes {
    enum Phase: String, Codable, Hashable {
        case workout
        case rest
    }

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
        /// 当前训练会话展示状态：训练正向计时或组间休息倒计时。
        var phase: Phase
        /// 已完成组数，供训练 phase 展示。
        var completedSetCount: Int
        /// 仍有未完成组的动作数，供训练 phase 展示。
        var remainingExerciseCount: Int
        /// 下一组结构化信息，用于灵动岛 expanded 与锁屏卡片展示动作、重量和次数。
        var nextSet: NextSet?
        /// 本次休息结束时刻（墙钟）。仅 `rest` phase 有值。
        var restEndDate: Date?
        /// 本次休息总时长（秒）。仅 `rest` phase 有值。
        var restTotalDuration: Double?
    }

    /// 本地训练会话 id，用于主 App 找回并更新同一场训练的 Activity。
    var workoutId: UUID
    /// 训练标题快照。
    var workoutTitle: String
    /// 本次训练正向计时起点。
    var startedAt: Date
}
