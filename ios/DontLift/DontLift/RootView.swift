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
    @Environment(\.scenePhase) private var scenePhase

    @State private var lastBackgroundedAt: Date?
    @State private var lastForegroundSyncStartedAt: Date?
    @State private var foregroundSyncTask: Task<Void, Never>?

    private static let foregroundSyncDelay: TimeInterval = 3
    private static let foregroundSyncStaleAfter: TimeInterval = 5 * 60
    private static let foregroundSyncCooldown: TimeInterval = 5 * 60

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

    private func handleAppBecameActive() {
        restTimer.handleAppBecameActive()
        RestTimerController.clearDeliveredRestNotification()
        historyStore.ensureLoaded(reason: .appLaunch)
        scheduleForegroundSyncIfNeeded()
    }

    private func scheduleForegroundSyncIfNeeded() {
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
            ProgressView().tint(Theme.Color.accent)
        }
        .preferredColorScheme(.light)
        .task {
            // 拉 GET /me 决定路由；失败时 refreshProfile 不会误判为「需补全」（保持门控 nil），
            // 这里做有限重试让瞬时失败自愈，避免停在加载态空转。
            var attempt = 0
            while session.needsProfileCompletion == nil && attempt < 5 {
                await session.refreshProfile()
                if session.needsProfileCompletion != nil { break }
                attempt += 1
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
}
