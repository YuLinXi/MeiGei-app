import SwiftUI

/// 主界面 Tab。当前含训练三件套 + 我的；饮食/Team 在后续任务补 tab。
struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { WorkoutListView() }
                .tabItem { Label("训练", systemImage: "figure.strengthtraining.traditional") }
            NavigationStack { PlanListView() }
                .tabItem { Label("计划", systemImage: "list.bullet.rectangle") }
            NavigationStack { ExerciseLibraryView() }
                .tabItem { Label("动作", systemImage: "dumbbell") }
            NavigationStack { FoodDiaryView() }
                .tabItem { Label("饮食", systemImage: "fork.knife") }
            NavigationStack { TeamListView() }
                .tabItem { Label("Team", systemImage: "person.3") }
            NavigationStack { SettingsView() }
                .tabItem { Label("我的", systemImage: "person.circle") }
        }
    }
}

/// 「我的」：账户信息 + 手动同步 + 退出。
struct SettingsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(SyncEngine.self) private var syncEngine

    var body: some View {
        List {
            Section("账户") {
                LabeledContent("用户", value: session.currentUserId?.uuidString.prefix(8).description ?? "已登录")
            }
            Section("同步") {
                LabeledContent("状态", value: syncEngine.isSyncing ? "同步中…" : "空闲")
                Button("立即同步") { Task { await syncEngine.syncAll() } }
                    .disabled(syncEngine.isSyncing)
            }
            Section {
                Button("退出登录", role: .destructive) { session.logout() }
            }
        }
        .navigationTitle("我的")
    }
}
