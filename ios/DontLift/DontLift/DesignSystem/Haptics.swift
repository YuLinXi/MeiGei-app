import AudioToolbox
import UIKit

extension Theme {
    /// 统一触感反馈封装。视图层 MUST NOT 直接 new `UI*FeedbackGenerator`，
    /// 一律走这里，便于触感语义一致与后续统一调参 / 全局开关。
    enum Haptics {
        /// 碰撞触感（轻 / 中 / 重）。用于点按类主动作（开始训练、继续等）。
        static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }

        /// 选择切换触感。用于离散状态跨阈（如左滑越过删除显露阈值）。
        static func selection() {
            UISelectionFeedbackGenerator().selectionChanged()
        }

        /// 通知触感（成功 / 警告 / 失败）。用于结果反馈（完成、删除确认等）。
        static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
            UINotificationFeedbackGenerator().notificationOccurred(type)
        }

        /// 休息结束触感：两次短促震动，区别于普通完成反馈。
        static func restComplete() {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1)
            }
        }
    }

    /// 「加一组」按钮反馈：轻点击声 + 轻触感。
    enum Feedback {
        private static let clickSoundId: SystemSoundID = 1104

        static func addSetTap() {
            Haptics.impact(.light)
            AudioServicesPlaySystemSound(clickSoundId)
        }
    }
}
