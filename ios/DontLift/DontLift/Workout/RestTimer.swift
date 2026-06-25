import ActivityKit
import AVFoundation
import Foundation
import os.log
import SwiftUI
import UIKit
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
    private static let log = Logger(subsystem: "com.yulinxi.app.DontLift", category: "RestTimer")

    struct CompletionEvent: Identifiable, Equatable {
        let id = UUID()
        let setId: UUID
        let elapsedSeconds: Int
        let startedAt: Date
        let completedAt: Date
        let plannedEndDate: Date
    }

    /// 默认休息时长（秒），持久化到 UserDefaults。
    var defaultDuration: TimeInterval {
        didSet { UserDefaults.standard.set(defaultDuration, forKey: Self.durationKey) }
    }

    /// 休息结束/完成时是否在前台震动（由全屏弹窗底部「震动」开关控制），持久化到 UserDefaults，默认开。
    /// 仅作用于前台 `Theme.Haptics`；后台本地通知的震动由系统设置裁决，不在此范围。
    var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: Self.hapticsKey) }
    }

    /// 休息结束时是否在前台播放提醒音效（全屏弹窗底部「声音」开关控制），持久化到 UserDefaults，默认开。
    /// 经 `AVAudioSession.playback` 播放，无视静音键（健身场景刚需）；后台到点的声音由本地通知承载。
    var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: Self.soundKey) }
    }

    /// 本次休息结束时刻；nil 表示当前无计时。
    private(set) var endDate: Date?
    /// 本次休息原始总时长（秒），用于 RestTimerSheet 圆环进度比例。
    private(set) var totalDuration: TimeInterval = 0
    /// 关联的下一个动作名，用于计时条与结束提醒文案（也是 3.8 Live Activity 的数据来源）。
    private(set) var contextLabel: String?
    /// 下一组结构化信息，用于 Live Activity 展示重量/次数；仅随本次休息生命周期存在。
    private(set) var contextNextSet: RestActivityAttributes.NextSet?
    /// 前台 ticker 写入，仅用于驱动 SwiftUI 每秒刷新。
    private(set) var tick: Date = .now
    /// 等待训练页消费的休息完成事件；页面切换/销毁期间保留，避免实际休息回写丢失。
    private(set) var completionEvent: CompletionEvent?

    /// 全屏休息弹窗是否展开（共享态：训练页 FAB 触发置真，根层 overlay 渲染，层级天然高于 Tab/Nav）。
    var isExpanded = false
    /// 下一组提示（markdown「下一组 · **动作名** 第 N 组」），由训练会话页在启动休息时写入，供全屏弹窗显示。
    var nextHint: String?

    private var ticker: Timer?
    private var activity: Activity<RestActivityAttributes>?
    private var activityEndTask: Task<Void, Never>?
    /// 本次休息对应的已完成组；nil 表示只展示计时，不产生训练页回写事件。
    private var activeSetId: UUID?
    /// 本次休息真实开始时刻，用于计算实际休息秒数。
    private var startedAt: Date?
    /// 当前休息是否经历过后台；用于避免后台通知已响后回前台再补播 App 内声音。
    private var backgroundedDuringCurrentRest = false
    /// 提醒音效播放器（懒加载并预备，复用同一实例）。
    private var audioPlayer: AVAudioPlayer?
    private static let durationKey = "dontlift.rest.defaultDuration"
    private static let hapticsKey = "dontlift.rest.hapticsEnabled"
    private static let soundKey = "dontlift.rest.soundEnabled"
    /// 休息结束本地通知标识（PushManager 据此在前台抑制其声音，避免与前台音效双响）。
    static let notificationId = "dontlift.rest.timer"
    /// 系统通知使用与 App 内一致的双响提示音，避免两套声音体验不一致。
    static let notificationSoundName = "rest_complete.caf"
    /// Live Activity 到点后自动消失的宽限秒数：给「00:00 + 一声提醒」留出可见窗口再收回。
    private static let dismissGrace: TimeInterval = 15
    /// 前台展示休息结束横幅后，延迟清掉通知中心残留；锁屏/后台场景等用户回到 App 再清理。
    private static let deliveredNotificationCleanupDelay: TimeInterval = 6

    init() {
        let saved = UserDefaults.standard.double(forKey: Self.durationKey)
        defaultDuration = saved > 0 ? saved : 90
        // 未设置过时默认开（object 取不到 → nil → true）。
        hapticsEnabled = (UserDefaults.standard.object(forKey: Self.hapticsKey) as? Bool) ?? true
        soundEnabled = (UserDefaults.standard.object(forKey: Self.soundKey) as? Bool) ?? true
        observeExternalEnd()
        observeAppBackground()
    }

    /// 是否有进行中的休息（剩余 > 0）。
    var isRunning: Bool { remaining > 0 }

    /// 剩余秒数（>= 0）。
    var remaining: TimeInterval {
        guard let endDate else { return 0 }
        return max(0, endDate.timeIntervalSinceNow)
    }

    /// 开始/重启一次休息倒计时，安排结束本地通知，并启动 Live Activity。
    func start(duration: TimeInterval? = nil,
               label: String? = nil,
               nextSet: RestActivityAttributes.NextSet? = nil,
               setId: UUID? = nil) {
        let secs = duration ?? defaultDuration
        let now = Date.now
        let end = now.addingTimeInterval(secs)
        endDate = end
        totalDuration = secs
        contextLabel = nextSet?.exerciseName ?? label
        contextNextSet = nextSet
        activeSetId = setId
        startedAt = now
        backgroundedDuringCurrentRest = false
        scheduleNotification(after: secs)
        startTicker()
        startActivity(totalDuration: secs, endDate: end, label: label, nextSet: nextSet)
    }

    /// 调整剩余时间（±秒，不低于 0），重排通知并重建 Live Activity。
    func adjust(by delta: TimeInterval) {
        guard let current = endDate else { return }
        let elapsed = max(0, totalDuration - remaining)
        let newEnd = max(Date.now, current.addingTimeInterval(delta))
        let newRemaining = max(0, newEnd.timeIntervalSinceNow)
        endDate = newEnd
        // “本次总时长”跟随用户调时后的计划时长，而不是固定停在启动值。
        totalDuration = elapsed + newRemaining
        scheduleNotification(after: newRemaining)
        // 已预约 .after 的 Live Activity 不可再 update，整体重建以反映新结束时刻并重排自动消失。
        startActivity(totalDuration: totalDuration, endDate: newEnd, label: contextLabel, nextSet: contextNextSet)
    }

    /// 提前结束 / 取消休息：清状态、撤销待发通知、结束 Live Activity。
    func stop() {
        clear()
        Self.clearRestNotifications(removePending: true, removeDelivered: true)
    }

    /// 手动提前完成休息：产生实际休息回写事件，但不播放结束音，避免与用户主动操作重复反馈。
    func completeEarly(now: Date = .now) {
        completeCurrentRest(now: now, playFeedback: false, endingActivity: true)
        Self.clearRestNotifications(removePending: true, removeDelivered: true)
    }

    /// 训练页在开始下一段休息前消费上一段休息，保留“提前进入下一组”的实际休息秒数。
    @discardableResult
    func completeForWriteback(now: Date = .now) -> CompletionEvent? {
        completeCurrentRest(now: now, playFeedback: false, endingActivity: true)
        return completionEvent
    }

    /// App 回到前台时兜底收束后台到点的休息。后台通知已负责提示音，这里不再补播。
    func handleAppBecameActive(now: Date = .now) {
        tick = now
        guard let endDate else {
            backgroundedDuringCurrentRest = false
            return
        }
        if endDate.timeIntervalSince(now) <= 0 {
            completeCurrentRest(now: now, playFeedback: false, endingActivity: false)
            Self.clearDeliveredRestNotification()
        } else {
            backgroundedDuringCurrentRest = false
        }
    }

    @discardableResult
    func consumeCompletionEvent(matching setIds: Set<UUID>) -> CompletionEvent? {
        guard let event = completionEvent, setIds.contains(event.setId) else { return nil }
        completionEvent = nil
        return event
    }

    /// 清理通知中心里已投递的休息结束通知；用于 App 回前台、用户点通知、开始下一次休息等可执行时机。
    static func clearDeliveredRestNotification() {
        clearRestNotifications(removePending: false, removeDelivered: true)
    }

    /// 前台横幅展示一小段时间后清理通知中心残留，不影响横幅本身的即时提醒。
    static func clearDeliveredRestNotificationSoon() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(deliveredNotificationCleanupDelay))
            clearDeliveredRestNotification()
        }
    }

    private func clear(endingActivity: Bool = true) {
        ticker?.invalidate()
        ticker = nil
        endDate = nil
        totalDuration = 0
        contextLabel = nil
        contextNextSet = nil
        nextHint = nil
        activeSetId = nil
        startedAt = nil
        backgroundedDuringCurrentRest = false
        // isExpanded 不在此清，交给根层 onChange(isRunning) 动画收起，保证渐隐。
        if endingActivity {
            endActivity()
        }
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.onTick() }
        }
    }

    private func onTick() {
        tick = .now
        // 前台到点：收起计时条，播一声提醒音（无视静音键）+ 按开关震动。
        // 同刻本地通知由 PushManager 在前台抑制其声音，避免双响。
        if let endDate, endDate.timeIntervalSinceNow <= 0 {
            // App 内休息态立即结束，但 Live Activity 继续停在 00:00 一小段时间，由 activityEndTask 自动收回。
            completeCurrentRest(now: .now,
                                playFeedback: !backgroundedDuringCurrentRest,
                                endingActivity: false)
        }
    }

    private func completeCurrentRest(now: Date, playFeedback: Bool, endingActivity: Bool) {
        recordCompletion(now: now)
        clear(endingActivity: endingActivity)
        if playFeedback {
            playEndSound()
            if hapticsEnabled { Theme.Haptics.restComplete() }
        }
    }

    private func recordCompletion(now: Date) {
        guard let setId = activeSetId, let startedAt else { return }
        let plannedEndDate = endDate ?? now
        let completedAt = min(now, plannedEndDate)
        let elapsed = max(0, min(totalDuration, completedAt.timeIntervalSince(startedAt)))
        completionEvent = CompletionEvent(setId: setId,
                                          elapsedSeconds: Int(elapsed.rounded()),
                                          startedAt: startedAt,
                                          completedAt: completedAt,
                                          plannedEndDate: plannedEndDate)
    }

    /// 前台播放一声休息结束提醒音：`AVAudioSession.playback` + duck，无视静音键、瞬时压低背景音乐。
    private func playEndSound() {
        guard soundEnabled else { return }
        if audioPlayer == nil,
           let url = Bundle.main.url(forResource: "rest_complete", withExtension: "caf") {
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
        }
        guard let player = audioPlayer else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.duckOthers, .mixWithOthers])
        try? session.setActive(true)
        player.currentTime = 0
        player.play()
        // 播完释放会话，让被 duck 的用户音乐恢复（不常驻激活）。
        let releaseAfter = player.duration + 0.3
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(releaseAfter))
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func scheduleNotification(after seconds: TimeInterval) {
        let center = UNUserNotificationCenter.current()
        Self.clearRestNotifications(removePending: true, removeDelivered: true)
        guard seconds > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "休息结束"
        content.body = contextLabel.map { "继续：\($0)" } ?? "开始下一组"
        // 后台/锁屏到点的提醒音由系统通知播放；前台音效由 AVAudioPlayer 播放同一份 caf。
        // 注意：通知声音仍服从静音键，静音下无声——突破静音需 Critical Alerts 特权（健身场景大概率被拒），不做。
        content.sound = UNNotificationSound(named: UNNotificationSoundName(Self.notificationSoundName))
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        center.add(UNNotificationRequest(identifier: Self.notificationId, content: content, trigger: trigger))
    }

    private static func clearRestNotifications(removePending: Bool, removeDelivered: Bool) {
        let center = UNUserNotificationCenter.current()
        if removePending {
            center.removePendingNotificationRequests(withIdentifiers: [notificationId])
        }
        if removeDelivered {
            center.removeDeliveredNotifications(withIdentifiers: [notificationId])
        }
    }

    // MARK: - Live Activity（3.8）

    private func startActivity(totalDuration: TimeInterval,
                               endDate: Date,
                               label: String?,
                               nextSet: RestActivityAttributes.NextSet?) {
        endActivity()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = RestActivityAttributes(totalDuration: totalDuration)
        let state = RestActivityAttributes.ContentState(endDate: endDate,
                                                        nextExercise: nextSet?.exerciseName ?? label,
                                                        nextSet: nextSet)
        let content = ActivityContent(state: state, staleDate: endDate)
        do {
            let act = try Activity.request(attributes: attributes, content: content, pushType: nil)
            activity = act
            Self.log.info("休息 Live Activity 已启动：\(act.id, privacy: .public)")

            // Live Activity 必须在倒计时期间保持 active，灵动岛才会持续展示。
            // 到点后由一个轻量任务结束活动；若 App 被系统挂起，回到前台的 ticker/stop 仍会兜底清理。
            let dismissDate = endDate.addingTimeInterval(Self.dismissGrace)
            activityEndTask = Task { [weak self] in
                let delay = max(0, dismissDate.timeIntervalSinceNow)
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                let shouldEnd = await MainActor.run { self?.activity?.id == act.id }
                guard shouldEnd else { return }
                await act.end(content, dismissalPolicy: .immediate)
                await MainActor.run {
                    if self?.activity?.id == act.id {
                        self?.activity = nil
                        self?.activityEndTask = nil
                    }
                }
            }
        } catch {
            Self.log.error("休息 Live Activity 启动失败：\(error.localizedDescription, privacy: .public)")
        }
    }

    private func endActivity() {
        activityEndTask?.cancel()
        activityEndTask = nil
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
            Task { @MainActor in self?.completeEarly() }
        }
    }

    private func observeAppBackground() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                if self?.endDate != nil {
                    self?.backgroundedDuringCurrentRest = true
                }
            }
        }
    }
}
