import SwiftUI

/// 登录门：未登录显示登录页；登录后进入主界面并触发同步 + 注册推送。
struct RootView: View {
    @Environment(SessionStore.self) private var session
    @Environment(SyncEngine.self) private var syncEngine
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if session.isLoggedIn {
                MainTabView()
                    .task {
                        PushManager.shared.requestAuthorizationAndRegister()
                        await syncEngine.syncAll()
                    }
                    .onChange(of: scenePhase) { _, phase in
                        if phase == .active {
                            Task { await syncEngine.syncAll() }
                        }
                    }
            } else {
                LoginView()
            }
        }
    }
}
