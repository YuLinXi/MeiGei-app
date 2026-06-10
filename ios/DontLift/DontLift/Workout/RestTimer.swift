import ActivityKit
import Foundation
import SwiftUI
import UserNotifications

extension Notification.Name {
    /// Live Activity 的「提前结束休息」App Intent 经 Darwin 通知跨进程送达后，转成本进程通知。
    static let dontliftRestEndedExternally = Notification.Name("dontlift.rest.endedExternally")
}

/// 3.7 组间休息计时器。
///
/// 计时基准是墙钟 `endDate`，剩余秒数始终由 `Date.now` 推算，因此 App 退到后台或锁屏都不影响正确性；
/// 回到前台时一次 tick 即可纠正显示。结束提醒交给本地通知（`UNTimeIntervalNotificationTrigger`），
/// 系统在后台/锁屏照常触发——通知权限已由 PushManager 在登录流程申请。
@MainActor
@Observable
final class RestTimerController {
    /// 默认休息时长（秒），持久化到 UserDefaults。
    var defaultDuration: TimeInterval {
        didSet { UserDefaults.standard.set(defaultDuration, forKey: Self.durationKey) }
    }

    /// 休息结束/完成时是否在前台震动（由全屏弹窗底部「震动」开关控制），持久化到 UserDefaults，默认开。
    /// 仅作用于前台 `Theme.Haptics`；后台本地通知的震动由系统设置裁决，不在此范围。
    var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: Self.hapticsKey) }
    }

    /// 本次休息结束时刻；nil 表示当前无计时。
    private(set) var endDate: Date?
    /// 本次休息原始总时长（秒），用于 RestTimerSheet 圆环进度比例。
    private(set) var totalDuration: TimeInterval = 0
    /// 关联的下一个动作名，用于计时条与结束提醒文案（也是 3.8 Live Activity 的数据来源）。
    private(set) var contextLabel: String?
    /// 前台 ticker 写入，仅用于驱动 SwiftUI 每秒刷新。
    private(set) var tick: Date = .now

    /// 全屏休息弹窗是否展开（共享态：训练页 FAB 触发置真，根层 overlay 渲染，层级天然高于 Tab/Nav）。
    var isExpanded = false
    /// 下一组提示（markdown「下一组 · **动作名** 第 N 组」），由训练会话页在启动休息时写入，供全屏弹窗显示。
    var nextHint: String?

    private var ticker: Timer?
    private var activity: Activity<RestActivityAttributes>?
    private static let durationKey = "dontlift.rest.defaultDuration"
    private static let hapticsKey = "dontlift.rest.hapticsEnabled"
    private static let notificationId = "dontlift.rest.timer"

    init() {
        let saved = UserDefaults.standard.double(forKey: Self.durationKey)
        defaultDuration = saved > 0 ? saved : 90
        // 未设置过时默认开（object 取不到 → nil → true）。
        hapticsEnabled = (UserDefaults.standard.object(forKey: Self.hapticsKey) as? Bool) ?? true
        observeExternalEnd()
    }

    /// 是否有进行中的休息（剩余 > 0）。
    var isRunning: Bool { remaining > 0 }

    /// 剩余秒数（>= 0）。
    var remaining: TimeInterval {
        guard let endDate else { return 0 }
        return max(0, endDate.timeIntervalSinceNow)
    }

    /// 开始/重启一次休息倒计时，安排结束本地通知，并启动 Live Activity。
    func start(duration: TimeInterval? = nil, label: String? = nil) {
        let secs = duration ?? defaultDuration
        let end = Date.now.addingTimeInterval(secs)
        endDate = end
        totalDuration = secs
        contextLabel = label
        scheduleNotification(after: secs)
        startTicker()
        startActivity(totalDuration: secs, endDate: end, label: label)
    }

    /// 调整剩余时间（±秒，不低于 0），重排通知并更新 Live Activity。
    func adjust(by delta: TimeInterval) {
        guard let current = endDate else { return }
        let newEnd = max(Date.now, current.addingTimeInterval(delta))
        endDate = newEnd
        scheduleNotification(after: newEnd.timeIntervalSinceNow)
        updateActivity(endDate: newEnd)
    }

    /// 提前结束 / 取消休息：清状态、撤销待发通知、结束 Live Activity。
    func stop() {
        clear()
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.notificationId])
    }

    private func clear() {
        ticker?.invalidate()
        ticker = nil
        endDate = nil
        totalDuration = 0
        contextLabel = nil
        nextHint = nil
        // isExpanded 不在此清，交给根层 onChange(isRunning) 动画收起，保证渐隐。
        endActivity()
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.onTick() }
        }
    }

    private func onTick() {
        tick = .now
        // 前台到点：本地通知同刻触发即为前台提醒，这里负责收起计时条并（按开关）震动。
        if let endDate, endDate.timeIntervalSinceNow <= 0 {
            clear()
            if hapticsEnabled { Theme.Haptics.notification(.success) }
        }
    }

    private func scheduleNotification(after seconds: TimeInterval) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationId])
        guard seconds > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "休息结束"
        content.body = contextLabel.map { "继续：\($0)" } ?? "开始下一组"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        center.add(UNNotificationRequest(identifier: Self.notificationId, content: content, trigger: trigger))
    }

    // MARK: - Live Activity（3.8）

    private func startActivity(totalDuration: TimeInterval, endDate: Date, label: String?) {
        endActivity()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = RestActivityAttributes(totalDuration: totalDuration)
        let state = RestActivityAttributes.ContentState(endDate: endDate, nextExercise: label)
        activity = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: endDate),
            pushType: nil)
    }

    private func updateActivity(endDate: Date) {
        guard let activity else { return }
        let state = RestActivityAttributes.ContentState(endDate: endDate, nextExercise: contextLabel)
        Task { await activity.update(ActivityContent(state: state, staleDate: endDate)) }
    }

    private func endActivity() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    /// 监听 widget「提前结束休息」App Intent 经 Darwin 通知送来的信号，在主进程同步清理。
    private func observeExternalEnd() {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                Task { @MainActor in NotificationCenter.default.post(name: .dontliftRestEndedExternally, object: nil) }
            },
            RestSignal.endRestName as CFString,
            nil,
            .deliverImmediately)
        NotificationCenter.default.addObserver(
            forName: .dontliftRestEndedExternally, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
    }
}

/// 训练页底部的休息计时条：剩余时间 + ±15s + 提前结束。
struct RestTimerBar: View {
    let controller: RestTimerController

    var body: some View {
        if controller.endDate != nil {
            // 读 tick 让本视图随 ticker 每秒刷新。
            let _ = controller.tick
            HStack(spacing: 12) {
                Image(systemName: "timer").font(.title3)
                Text(format(controller.remaining))
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .frame(minWidth: 56, alignment: .leading)
                if let label = controller.contextLabel {
                    Text(label).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button("−15") { controller.adjust(by: -15) }.buttonStyle(.bordered)
                Button("+15") { controller.adjust(by: 15) }.buttonStyle(.bordered)
                Button("结束") { controller.stop() }.buttonStyle(.borderedProminent)
            }
            .font(.subheadline)
            .padding(.horizontal).padding(.vertical, 10)
            .background(.bar)
        }
    }

    private func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
