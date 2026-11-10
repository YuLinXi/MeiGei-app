import SwiftUI
import SwiftData

/// 登录门：未登录显示登录页；登录后按后端画像决定首登补全页 or 主界面。
/// 门控信号 `session.needsProfileCompletion` 由 `GET /me` 拉取后置位（nil = 拉取中）。
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionStore.self) private var session
    @Environment(SyncEngine.self) private var syncEngine
    @Environment(WorkoutHistoryStore.self) private var historyStore
    @Environment(TeamService.self) private var teamService
    @Environment(RestTimerController.self) private var restTimer
    @Environment(WorkoutLiveActivityController.self) private var workoutLiveActivity
    @Environment(\.scenePhase) private var scenePhase

    @State private var lastBackgroundedAt: Date?
    @State private var lastForegroundSyncStartedAt: Date?
    @State private var foregroundSyncTask: Task<Void, Never>?

    private static let foregroundSyncDelay: TimeInterval = 3
    private static let foregroundSyncStaleAfter: TimeInterval = 5 * 60
    private static let foregroundSyncCooldown: TimeInterval = 5 * 60

    var body: some View {
        Group {
            if session.requiresLocalCleanup {
                cleanupGate
            } else if session.isLoggedIn {
                switch session.needsProfileCompletion {
                case .some(false):
                    mainApp
                case .some(true):
                    ProfileCompletionView()
                        .id(session.currentUserId)
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
        mainAppContent
            .task {
                #if DEBUG
                // UI 测试场景：跳过推送授权与同步（假 token 打后端会 401 触发全局登出）。
                if UITestHooks.isLiveWorkoutUITest || UITestHooks.isAutoLogin {
                    restTimer.handleAppBecameActive()
                    RestTimerController.clearDeliveredRestNotification()
                    historyStore.ensureLoaded(reason: .login)
                    return
                }
                #endif
                PushManager.shared.requestAuthorizationAndRegister()
                restTimer.handleAppBecameActive()
                RestTimerController.clearDeliveredRestNotification()
                historyStore.ensureLoaded(reason: .login)
                await syncEngine.syncAll()
            }
            .onReceive(NotificationCenter.default.publisher(for: .dontliftSyncCompleted)) { _ in
                historyStore.scheduleRefresh(reason: .syncCompleted)
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    handleAppBecameActive()
                case .background:
                    lastBackgroundedAt = .now
                    cancelForegroundSyncTask()
                default:
                    break
                }
            }
    }

    @ViewBuilder private var mainAppContent: some View {
        #if DEBUG
        if UITestHooks.isBulkSyncUITest {
            MainTabView()
                .overlay(alignment: .topTrailing) { UITestBulkSyncProgress() }
        } else if UITestHooks.isTeamSharingUITest {
            UITestTeamSharingFixture()
        } else if UITestHooks.isHistoryLoadingUITest {
            MainTabView()
                .overlay(alignment: .topTrailing) { UITestHistoryReadCounter() }
        } else if UITestHooks.isAutoLogin,
           ProcessInfo.processInfo.arguments.contains("-uitest-native-controls") {
            UITestNativeControlsFixture()
        } else {
            MainTabView()
        }
        #else
        MainTabView()
        #endif
    }

    private var cleanupGate: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.lg) {
                Text(session.localCleanupFailed ? "本机数据尚未清理完成" : "正在清理本机数据")
                    .font(Theme.Font.l2)
                    .foregroundStyle(Theme.Color.fg)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("accountCleanup.title")
                Text("账号已删除。完成本机清理后可重新登录。")
                    .font(Theme.Font.l4)
                    .foregroundStyle(Theme.Color.fg2)
                    .multilineTextAlignment(.center)
                if session.localCleanupFailed {
                    Button("重试清理") { session.retryLocalCleanup() }
                        .frame(minWidth: 120, minHeight: 44)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.Color.action)
                        .accessibilityIdentifier("accountCleanup.retry")
                } else {
                    ProgressView().tint(Theme.Color.action)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .task {
            // 先移除原页面及其编辑回调，再清理旧数据。
            await Task.yield()
            guard !Task.isCancelled else { return }
            session.retryLocalCleanup()
        }
    }

    private func handleAppBecameActive() {
        restTimer.handleAppBecameActive()
        workoutLiveActivity.reconcile(activeWorkout: WorkoutSession.activeSession(in: modelContext))
        RestTimerController.clearDeliveredRestNotification()
        historyStore.ensureLoaded(reason: .appLaunch)
        scheduleForegroundSyncIfNeeded()
    }

    private func scheduleForegroundSyncIfNeeded() {
        #if DEBUG
        if UITestHooks.isLiveWorkoutUITest || UITestHooks.isAutoLogin { return }
        #endif
        guard let backgroundedAt = lastBackgroundedAt else { return }
        lastBackgroundedAt = nil
        cancelForegroundSyncTask()
        foregroundSyncTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.foregroundSyncDelay))
            guard !Task.isCancelled else { return }
            await runForegroundSyncIfNeeded(backgroundedAt: backgroundedAt)
        }
    }

    private func runForegroundSyncIfNeeded(backgroundedAt: Date) async {
        defer { foregroundSyncTask = nil }
        guard !syncEngine.isSyncing else {
            WorkoutPerformanceMonitor.event("foreground.sync.skipped")
            return
        }
        guard shouldRunForegroundSync(backgroundedAt: backgroundedAt) else {
            WorkoutPerformanceMonitor.event("foreground.sync.skipped")
            return
        }
        lastForegroundSyncStartedAt = .now
        WorkoutPerformanceMonitor.event("foreground.sync.started")
        await syncEngine.syncAll()
    }

    private func shouldRunForegroundSync(backgroundedAt: Date) -> Bool {
        let now = Date.now
        if let lastForegroundSyncStartedAt,
           now.timeIntervalSince(lastForegroundSyncStartedAt) < Self.foregroundSyncCooldown {
            return false
        }

        let activeWorkoutId = WorkoutSession.activeSession(in: modelContext)?.localId
        if syncEngine.hasPendingLocalChanges(excludingWorkoutId: activeWorkoutId) {
            return true
        }

        if let userId = session.currentUserId {
            let hasPendingShare = !teamService.pendingShareWorkoutIds(userId: userId).isEmpty
            let hasPendingPlanEvent = teamService.hasPendingPlanShareEvents(userId: userId)
            if hasPendingShare || hasPendingPlanEvent {
                return true
            }
        }

        guard activeWorkoutId == nil else { return false }
        return now.timeIntervalSince(backgroundedAt) >= Self.foregroundSyncStaleAfter
    }

    private func cancelForegroundSyncTask() {
        foregroundSyncTask?.cancel()
        foregroundSyncTask = nil
    }

    private var loadingGate: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            if session.profileLoadFailed {
                VStack(spacing: Theme.Spacing.lg) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(Theme.Font.hero)
                        .foregroundStyle(Theme.Color.fg2)
                        .accessibilityHidden(true)
                    Text("暂时无法读取账号资料")
                        .font(Theme.Font.l2)
                        .foregroundStyle(Theme.Color.fg)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("profileGate.failure")
                    Text("请检查网络后重试，或返回登录。\n本机已有的训练与计划不会被删除。")
                        .font(Theme.Font.l4)
                        .foregroundStyle(Theme.Color.fg2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        Task { await session.resolveProfile() }
                    } label: {
                        Text("重试")
                            .frame(minWidth: 88, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.Color.fg)
                    .accessibilityIdentifier("profileGate.retry")
                    returnToLoginButton
                }
                .padding(Theme.Spacing.xl)
            } else {
                VStack(spacing: Theme.Spacing.lg) {
                    ProgressView("正在读取账号资料…")
                        .tint(Theme.Color.action)
                        .foregroundStyle(Theme.Color.fg2)
                        .accessibilityIdentifier("profileGate.loading")
                    returnToLoginButton
                }
                .padding(Theme.Spacing.xl)
            }
        }
        .preferredColorScheme(.light)
        .task {
            await session.resolveProfile()
        }
    }

    private var returnToLoginButton: some View {
        Button { session.logout() } label: {
            Text("返回登录")
                .font(Theme.Font.l3)
                .frame(minWidth: 88, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.Color.fg2)
        .accessibilityIdentifier("profileGate.login")
    }
}
