import SwiftUI
import UIKit

/// 主界面 Tab：训练三件套 + Team + 我的（饮食模块已移出 MVP）。
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
            NavigationStack { TeamListView() }
                .tabItem { Label("Team", systemImage: "person.3") }
            NavigationStack { ProfileView() }
                .tabItem { Label("我的", systemImage: "person.circle") }
        }
        .tint(Theme.Color.accentCyan)
        .toolbarBackground(Theme.Color.bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

