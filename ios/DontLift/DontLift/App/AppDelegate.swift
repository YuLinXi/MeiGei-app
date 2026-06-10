import UIKit

/// 承接 APNs 注册回调（SwiftUI 经 UIApplicationDelegateAdaptor 桥接）。
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in PushManager.shared.didRegister(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // 模拟器或无网络时会失败，忽略即可。
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async
        -> UIBackgroundFetchResult {
        await PushManager.shared.handleRemoteNotification(userInfo)
        return .newData
    }
}
