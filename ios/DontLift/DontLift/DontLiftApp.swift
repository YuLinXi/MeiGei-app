import SwiftUI
import SwiftData

@main
struct DontLiftApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    let modelContainer: ModelContainer
    @State private var session: SessionStore
    @State private var syncEngine: SyncEngine
    @State private var historyStore: WorkoutHistoryStore
    @State private var teamService = TeamService()
    @State private var restTimer: RestTimerController
    @State private var workoutLiveActivity: WorkoutLiveActivityController
    @State private var healthKit = HealthKitManager()
    @State private var prCelebration = PRCelebrationCenter()
    @State private var planWriteback = PlanWritebackCenter()
    @State private var teamShare = TeamShareCenter()
    @State private var globalMessage = GlobalMessageCenter()
    @State private var syncProgress = SyncProgressCenter()
    @State private var workoutPresentation = WorkoutPresentationCenter()
    @State private var badgeCelebration = BadgeCelebrationCenter()
    @State private var badgeWallStore = BadgeWallStore()

    init() {
        let container = AppModelContainer.make()
        #if DEBUG
        // UI 测试钩子：播种进行中训练；假登录态在 SessionStore 创建后注入（内存态，绕开无签名 build 的 Keychain 限制）。
        UITestHooks.seedLiveWorkoutIfNeeded(container: container)
        UITestHooks.clearActiveWorkoutIfNeeded(container: container)
        UITestHooks.configureLaunchEnvironment()
        #endif
        self.modelContainer = container
        // 同名动作历史合并（一次性本地迁移，幂等）：把旧手填记录挂到同名内置动作 code，避免历史断裂。
        ExerciseHistoryMerge.runIfNeeded(in: container.mainContext)
        let session = SessionStore(modelContext: container.mainContext)
        #if DEBUG
        if UITestHooks.isLiveWorkoutUITest || UITestHooks.isAutoLogin {
            session.uitestInjectFakeSession()
        }
        if UITestHooks.isSeedDemoData {
            UITestHooks.seedDemoDataAndBadges(in: container.mainContext)
        }
        #endif
        let historyStore = WorkoutHistoryStore(modelContext: container.mainContext)
        let workoutLiveActivity = WorkoutLiveActivityController()
        _session = State(initialValue: session)
        _syncEngine = State(initialValue: SyncEngine(modelContext: container.mainContext))
        _historyStore = State(initialValue: historyStore)
        _workoutLiveActivity = State(initialValue: workoutLiveActivity)
        _restTimer = State(initialValue: RestTimerController(liveActivityController: workoutLiveActivity))
        PushManager.shared.isLoggedIn = { session.isLoggedIn }
        Theme.Font.verifyOrFallback()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                GlobalOverlayWindowHost()
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
                .environment(session)
                .environment(syncEngine)
                .environment(historyStore)
                .environment(teamService)
                .environment(restTimer)
                .environment(workoutLiveActivity)
                .environment(healthKit)
                .environment(prCelebration)
                .environment(planWriteback)
                .environment(teamShare)
                .environment(globalMessage)
                .environment(syncProgress)
                .environment(workoutPresentation)
                .environment(badgeCelebration)
                .environment(badgeWallStore)
                .preferredColorScheme(.light)
                .onChange(of: session.currentUserId, initial: true) { _, userId in
                    badgeWallStore.configure(context: modelContainer.mainContext, userId: userId)
                }
                .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { notification in
                    badgeWallStore.saved(notification)
                }
                .onReceive(NotificationCenter.default.publisher(for: .badgeBodyWeightChanged)) { _ in
                    badgeWallStore.invalidate(historyChanged: false)
                }
                .task(id: session.isLoggedIn) {
                    #if DEBUG
                    // UI 测试场景跳过 HealthKit 授权弹窗，避免阻塞自动化。
                    if UITestHooks.isLiveWorkoutUITest || UITestHooks.isAutoLogin { return }
                    #endif
                    if session.isLoggedIn { await healthKit.requestAuthorization() }
                }
        }
        .modelContainer(modelContainer)
    }
}
