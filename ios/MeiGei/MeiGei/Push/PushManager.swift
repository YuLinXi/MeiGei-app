import Foundation
import UIKit
import UserNotifications

extension Notification.Name {
    /// 收到「新打卡」推送（userInfo 含 teamId）。Team 页据此刷新。
    static let meigeiCheckinReceived = Notification.Name("meigei.push.checkin")
    /// 收到「表情回应」推送（userInfo 含 checkinId/emoji）。
    static let meigeiReactionReceived = Notification.Name("meigei.push.reaction")
}

/// APNs 注册、token 上报与下行推送路由（2.9）。
@MainActor
final class PushManager: NSObject {
    static let shared = PushManager()

    /// 设备 token（hex）；登录后才能带 Bearer 上报，故先缓存。
    private var deviceTokenHex: String?
    /// 当前是否已登录（由 App 注入），决定能否上报 token。
    var isLoggedIn: () -> Bool = { false }

    /// 请求通知权限并注册 APNs。
    func requestAuthorizationAndRegister() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
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
            NotificationCenter.default.post(name: .meigeiReactionReceived, object: nil, userInfo: userInfo)
        } else if userInfo["teamId"] != nil {
            NotificationCenter.default.post(name: .meigeiCheckinReceived, object: nil, userInfo: userInfo)
        }
    }
}

extension PushManager: UNUserNotificationCenterDelegate {
    /// 前台也展示横幅。
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        handleRemoteNotification(notification.request.content.userInfo)
        return [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        handleRemoteNotification(response.notification.request.content.userInfo)
    }
}
