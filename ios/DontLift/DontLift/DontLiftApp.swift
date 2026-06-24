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
    @State private var restTimer = RestTimerController()
    @State private var healthKit = HealthKitManager()
    @State private var prCelebration = PRCelebrationCenter()
    @State private var planWriteback = PlanWritebackCenter()
    @State private var teamShare = TeamShareCenter()

    init() {
        let container = AppModelContainer.make()
        self.modelContainer = container
        // 同名动作历史合并（一次性本地迁移，幂等）：把旧手填记录挂到同名内置动作 code，避免历史断裂。
        ExerciseHistoryMerge.runIfNeeded(in: container.mainContext)
        let session = SessionStore(modelContext: container.mainContext)
        let historyStore = WorkoutHistoryStore(modelContext: container.mainContext)
        _session = State(initialValue: session)
        _syncEngine = State(initialValue: SyncEngine(modelContext: container.mainContext))
        _historyStore = State(initialValue: historyStore)
        PushManager.shared.isLoggedIn = { session.isLoggedIn }
        Theme.Font.verifyOrFallback()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(syncEngine)
                .environment(historyStore)
                .environment(teamService)
                .environment(restTimer)
                .environment(healthKit)
                .environment(prCelebration)
                .environment(planWriteback)
                .environment(teamShare)
                .preferredColorScheme(.light)
                .task(id: session.isLoggedIn) {
                    if session.isLoggedIn { await healthKit.requestAuthorization() }
                }
        }
        .modelContainer(modelContainer)
    }
}
