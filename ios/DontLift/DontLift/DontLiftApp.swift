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
        UITestHooks.seedHistorySaveSamplesIfNeeded(container: container)
        UITestHooks.seedProfileRecoveryIfNeeded(container: container)
        UITestHooks.seedPlanSaveRecoveryIfNeeded(container: container)
        UITestHooks.seedPlanReadabilityIfNeeded(container: container)
        UITestHooks.seedBadgeReadabilityIfNeeded(container: container)
        UITestHooks.configureLaunchEnvironment()
        #endif
        self.modelContainer = container
        let session: SessionStore
        #if DEBUG
        if UITestHooks.isProfileRecoveryUITest || UITestHooks.isProfileCompletionUITest {
            session = SessionStore(modelContext: container.mainContext,
                                   profileDefaults: UserDefaults(suiteName: "dontlift.uitest.profileRecovery") ?? .standard,
                                   loadProfile: { try UITestHooks.profileRecoveryResponse() },
                                   updateProfile: { try UITestHooks.profileCompletionResponse($0) })
        } else if UITestHooks.isLiveWorkoutUITest || UITestHooks.isAutoLogin {
            session = SessionStore(modelContext: container.mainContext,
                                   profileDefaults: UserDefaults(suiteName: UITestHooks.isLocalCleanupRecoveryUITest
                                                               ? "dontlift.uitest.cleanup" : "dontlift.uitest.session")!,
                                   loadProfile: { UITestHooks.profileUpdateResponse(.init(displayName: "测试用户", sex: "male")) },
                                   updateProfile: { UITestHooks.profileUpdateResponse($0) })
        } else {
            session = SessionStore(modelContext: container.mainContext)
        }
        if UITestHooks.isLiveWorkoutUITest || UITestHooks.isAutoLogin {
            session.uitestInjectFakeSession(profileResolved: !UITestHooks.isProfileRecoveryUITest
                                           && !UITestHooks.isProfileCompletionUITest)
        }
        if UITestHooks.isLocalCleanupRecoveryUITest { session.beginDeletedAccountCleanup() }
        if UITestHooks.isSeedDemoData {
            UITestHooks.seedDemoDataAndBadges(in: container.mainContext)
        }
        if UITestHooks.isTeamReadabilityUITest, let userId = session.currentUserId {
            _teamService = State(initialValue: UITestHooks.teamReadabilityService(userId: userId))
        }
        #else
        session = SessionStore(modelContext: container.mainContext)
        #endif
        if !session.requiresLocalCleanup {
            // 同名动作历史合并一次性执行；待清理缓存不再进入正常启动迁移。
            ExerciseHistoryMerge.runIfNeeded(in: container.mainContext)
        }
        #if DEBUG
        let historyStore = UITestHooks.makeHistoryStore(modelContext: container.mainContext)
        #else
        let historyStore = WorkoutHistoryStore(modelContext: container.mainContext)
        #endif
        let workoutLiveActivity = WorkoutLiveActivityController()
        _session = State(initialValue: session)
        let syncEngine: SyncEngine
        #if DEBUG
        if UITestHooks.isSyncRecoveryUITest {
            syncEngine = UITestHooks.syncRecoveryEngine(context: container.mainContext)
        } else {
            syncEngine = SyncEngine(modelContext: container.mainContext, canSync: { [weak session] in
                session?.isLoggedIn == true && session?.requiresLocalCleanup == false
            })
        }
        #else
        syncEngine = SyncEngine(modelContext: container.mainContext, canSync: { [weak session] in
            session?.isLoggedIn == true && session?.requiresLocalCleanup == false
        })
        #endif
        _syncEngine = State(initialValue: syncEngine)
        session.onSessionInvalidated = { syncEngine.resetResult() }
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
                #if DEBUG
                .task { UITestHooks.applyTypographyTraits() }
                #endif
                .onChange(of: session.currentUserId, initial: true) { oldUserId, userId in
                    if oldUserId != userId { planWriteback.clearRetainedReceipt() }
                    historyStore.reset()
                    if userId == nil { restTimer.stop() }
                    badgeWallStore.configure(context: modelContainer.mainContext, userId: userId)
                }
                .onReceive(NotificationCenter.default.publisher(for: LocalModelSave.didSave)) { notification in
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
