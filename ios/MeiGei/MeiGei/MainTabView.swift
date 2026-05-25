import SwiftUI
import UIKit

/// 主界面 Tab。当前含训练三件套 + 我的；饮食/Team 在后续任务补 tab。
struct MainTabView: View {
    init() {
        // 7.1 Tab bar 黑底配置：避免亮色穿透。
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(named: "bg") ?? .black
        appearance.shadowColor = UIColor(named: "border") ?? .darkGray
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        // 7.2 Navigation bar 黑底 + dark color scheme。
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(named: "bg") ?? .black
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(named: "fg") ?? .white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(named: "fg") ?? .white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
    }

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
        .tint(Theme.Color.accentCyan)
        .toolbarBackground(Theme.Color.bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

/// 「我的」：账户信息 + 手动同步 + 退出。
struct SettingsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(SyncEngine.self) private var syncEngine

    @State private var versionTapCount = 0
    @State private var showDesignSystem = false

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

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
            Section("关于") {
                LabeledContent("版本", value: appVersion)
                    .contentShape(Rectangle())
                    .onTapGesture { handleVersionTap() }
            }
            Section {
                Button("退出登录", role: .destructive) { session.logout() }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Color.bg)
        .navigationTitle("我的")
        #if DEBUG
        .navigationDestination(isPresented: $showDesignSystem) {
            DesignSystemPreviewView()
        }
        #endif
    }

    private func handleVersionTap() {
        #if DEBUG
        versionTapCount += 1
        if versionTapCount >= 5 {
            versionTapCount = 0
            showDesignSystem = true
        }
        #endif
    }
}
