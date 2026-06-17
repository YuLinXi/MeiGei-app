import ActivityKit
import AVFoundation
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
    /// 前台 ticker 写入，仅用于驱动 SwiftUI 每秒刷新。
    private(set) var tick: Date = .now

    /// 全屏休息弹窗是否展开（共享态：训练页 FAB 触发置真，根层 overlay 渲染，层级天然高于 Tab/Nav）。
    var isExpanded = false
    /// 下一组提示（markdown「下一组 · **动作名** 第 N 组」），由训练会话页在启动休息时写入，供全屏弹窗显示。
    var nextHint: String?

    private var ticker: Timer?
    private var activity: Activity<RestActivityAttributes>?
    /// 提醒音效播放器（懒加载并预备，复用同一实例）。
    private var audioPlayer: AVAudioPlayer?
    private static let durationKey = "dontlift.rest.defaultDuration"
    private static let hapticsKey = "dontlift.rest.hapticsEnabled"
    private static let soundKey = "dontlift.rest.soundEnabled"
    /// 休息结束本地通知标识（PushManager 据此在前台抑制其声音，避免与前台音效双响）。
    static let notificationId = "dontlift.rest.timer"
    /// Live Activity 到点后自动消失的宽限秒数：给「00:00 + 一声提醒」留出可见窗口再收回。
    private static let dismissGrace: TimeInterval = 2

    init() {
        let saved = UserDefaults.standard.double(forKey: Self.durationKey)
        defaultDuration = saved > 0 ? saved : 90
        // 未设置过时默认开（object 取不到 → nil → true）。
        hapticsEnabled = (UserDefaults.standard.object(forKey: Self.hapticsKey) as? Bool) ?? true
        soundEnabled = (UserDefaults.standard.object(forKey: Self.soundKey) as? Bool) ?? true
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

    /// 调整剩余时间（±秒，不低于 0），重排通知并重建 Live Activity。
    func adjust(by delta: TimeInterval) {
        guard let current = endDate else { return }
        let newEnd = max(Date.now, current.addingTimeInterval(delta))
        endDate = newEnd
        scheduleNotification(after: newEnd.timeIntervalSinceNow)
        // 已预约 .after 的 Live Activity 不可再 update，整体重建以反映新结束时刻并重排自动消失。
        startActivity(totalDuration: totalDuration, endDate: newEnd, label: contextLabel)
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
        // 前台到点：收起计时条，播一声提醒音（无视静音键）+ 按开关震动。
        // 同刻本地通知由 PushManager 在前台抑制其声音，避免双响。
        if let endDate, endDate.timeIntervalSinceNow <= 0 {
            clear()
            playEndSound()
            if hapticsEnabled { Theme.Haptics.notification(.success) }
        }
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
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationId])
        guard seconds > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "休息结束"
        content.body = contextLabel.map { "继续：\($0)" } ?? "开始下一组"
        // 后台/锁屏到点的提醒音用自定义 caf（与前台 playEndSound 同源），而非系统默认音。
        // 注意：通知声音仍服从静音键，静音下无声——突破静音需 Critical Alerts 特权（健身场景大概率被拒），不做。
        content.sound = UNNotificationSound(named: UNNotificationSoundName("rest_complete.caf"))
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
        let content = ActivityContent(state: state, staleDate: endDate)
        guard let act = try? Activity.request(attributes: attributes, content: content, pushType: nil) else { return }
        activity = act
        // 启动即预约「到点后自动消失」：把 dismiss 时机交给系统，后台/锁屏无需唤醒即可收回灵动岛。
        // ended 态下 Text(timerInterval:) 仍自走倒计时，灵动岛在 endDate+grace 前持续显示后自动隐去。
        // 注意：end 后 activity 不可再 update，故 adjust(±10s) 走整体重建（见 adjust）。
        Task { await act.end(content, dismissalPolicy: .after(endDate.addingTimeInterval(Self.dismissGrace))) }
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
