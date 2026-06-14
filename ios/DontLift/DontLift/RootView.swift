import SwiftUI

/// 登录门：未登录显示登录页；登录后按后端画像决定首登补全页 or 主界面。
/// 门控信号 `session.needsProfileCompletion` 由 `GET /me` 拉取后置位（nil = 拉取中）。
struct RootView: View {
    @Environment(SessionStore.self) private var session
    @Environment(SyncEngine.self) private var syncEngine
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if session.isLoggedIn {
                switch session.needsProfileCompletion {
                case .some(false):
                    mainApp
                case .some(true):
                    ProfileCompletionView()
                case .none:
                    // 冷启动已登录但尚未拉到画像：先拉 GET /me 决定路由，期间纸白加载态。
                    loadingGate
                }
            } else {
                LoginView()
            }
        }
    }

    private var mainApp: some View {
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
    }

    private var loadingGate: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            ProgressView().tint(Theme.Color.accent)
        }
        .preferredColorScheme(.light)
        .task { await session.refreshProfile() }
    }
}
