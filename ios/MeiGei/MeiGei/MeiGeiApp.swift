import SwiftUI
import SwiftData

@main
struct MeiGeiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    let modelContainer: ModelContainer
    @State private var session: SessionStore
    @State private var syncEngine: SyncEngine
    @State private var teamService = TeamService()
    @State private var restTimer = RestTimerController()
    @State private var healthKit = HealthKitManager()

    init() {
        let container = AppModelContainer.make()
        self.modelContainer = container
        let session = SessionStore(modelContext: container.mainContext)
        _session = State(initialValue: session)
        _syncEngine = State(initialValue: SyncEngine(modelContext: container.mainContext))
        PushManager.shared.isLoggedIn = { session.isLoggedIn }
        Theme.Font.verifyOrFallback()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(syncEngine)
                .environment(teamService)
                .environment(restTimer)
                .environment(healthKit)
                .preferredColorScheme(.dark)
                .task(id: session.isLoggedIn) {
                    if session.isLoggedIn { await healthKit.requestAuthorization() }
                }
        }
        .modelContainer(modelContainer)
    }
}
