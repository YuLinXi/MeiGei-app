import Foundation
import OSLog
import UIKit
import UserNotifications

extension Notification.Name {
    /// 收到「新打卡」推送（userInfo 含 teamId）。Team 页据此刷新。
    static let dontliftCheckinReceived = Notification.Name("dontlift.push.checkin")
    /// 收到「表情回应」推送（userInfo 含 checkinId/emoji）。
    static let dontliftReactionReceived = Notification.Name("dontlift.push.reaction")
}

/// APNs 注册、token 上报与下行推送路由（2.9）。
@MainActor
final class PushManager: NSObject {
    static let shared = PushManager()
    private static let log = Logger(subsystem: "com.yulinxi.app.DontLift", category: "Push")

    /// 设备 token（hex）；登录后才能带 Bearer 上报，故先缓存。
    private var deviceTokenHex: String?
    /// 当前是否已登录（由 App 注入），决定能否上报 token。
    var isLoggedIn: () -> Bool = { false }

    /// 请求通知权限并注册 APNs。
    func requestAuthorizationAndRegister() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            Task { @MainActor in
                #if DEBUG
                await self.logNotificationSettings(reason: granted ? "authorization granted" : "authorization denied")
                #endif
            }
            guard granted else { return }
            Task { @MainActor in UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    func didRegister(deviceToken: Data) {
        deviceTokenHex = deviceToken.map { String(format: "%02x", $0) }.joined()
        registerWithBackendIfReady()
    }

    /// 登录成功后调用，把此前缓存的 token 上报。
    func registerWithBackendIfReady() {
        guard isLoggedIn(), let hex = deviceTokenHex else { return }
        Task {
            try? await APIClient.shared.sendVoid(
                "POST", "/devices/token",
                body: RegisterTokenRequest(apnsToken: hex, environment: AppConfig.apnsEnvironment))
        }
    }

    /// 路由下行推送到对应通知，供 Team 页拉取最新数据（design.md D6）。
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        if userInfo["emoji"] != nil || userInfo["checkinId"] != nil {
            NotificationCenter.default.post(name: .dontliftReactionReceived, object: nil, userInfo: userInfo)
        } else if userInfo["teamId"] != nil {
            NotificationCenter.default.post(name: .dontliftCheckinReceived, object: nil, userInfo: userInfo)
        }
    }

    #if DEBUG
    func logNotificationSettings(reason: String) async {
        let summary = await notificationDiagnosticSummary()
        Self.log.info("通知设置[\(reason, privacy: .public)] \(summary, privacy: .public)")
    }

    func notificationDiagnosticSummary() async -> String {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return [
            "auth=\(describe(settings.authorizationStatus))",
            "alert=\(describe(settings.alertSetting))",
            "sound=\(describe(settings.soundSetting))",
            "badge=\(describe(settings.badgeSetting))",
            "lock=\(describe(settings.lockScreenSetting))",
            "center=\(describe(settings.notificationCenterSetting))",
            "timeSensitive=\(describe(settings.timeSensitiveSetting))",
            "critical=\(describe(settings.criticalAlertSetting))"
        ].joined(separator: " ")
    }

    private func describe(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .provisional: return "provisional"
        case .ephemeral: return "ephemeral"
        @unknown default: return "unknown"
        }
    }

    private func describe(_ setting: UNNotificationSetting) -> String {
        switch setting {
        case .notSupported: return "notSupported"
        case .disabled: return "disabled"
        case .enabled: return "enabled"
        @unknown default: return "unknown"
        }
    }
    #endif
}

extension PushManager: UNUserNotificationCenterDelegate {
    /// 前台也展示横幅。
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        handleRemoteNotification(notification.request.content.userInfo)
        #if DEBUG
        Self.log.info("前台展示通知 id=\(notification.request.identifier, privacy: .public)")
        #endif
        // 休息结束本地通知：前台声音由 RestTimer 的 AVAudioPlayer 负责（无视静音键），
        // 这里抑制通知自带声音，避免前台双响；横幅仍展示。
        if notification.request.identifier == RestTimerController.notificationId {
            RestTimerController.clearDeliveredRestNotificationSoon()
            return [.banner]
        }
        return [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        handleRemoteNotification(response.notification.request.content.userInfo)
        if response.notification.request.identifier == RestTimerController.notificationId {
            RestTimerController.clearDeliveredRestNotification()
        }
    }
}
