import SwiftUI
import UIKit

/// 主界面 Tab：训练三件套 + Team + 我的（饮食模块已移出 MVP）。
struct MainTabView: View {
    @Environment(RestTimerController.self) private var restTimer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 休息全屏弹窗开/关动画：纯渐隐（无位移）。
    private var restAnim: Animation { .easeInOut(duration: reduceMotion ? 0.2 : 0.3) }

    init() {
        // Tab bar 纸感配置（对齐设计图 .tabs）：纸白底 + 顶部 border 分隔线；
        // 未选 muted / 选中 accent；label fs-l5=10。
        let muted = UIColor(named: "muted") ?? .gray
        let accent = UIColor(named: "accent") ?? .systemRed
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(named: "bg") ?? .white
        appearance.shadowColor = UIColor(named: "border") ?? .lightGray

        func style(_ item: UITabBarItemAppearance) {
            item.normal.iconColor = muted
            item.normal.titleTextAttributes = [
                .foregroundColor: muted,
                .font: UIFont.systemFont(ofSize: 10, weight: .regular)
            ]
            item.selected.iconColor = accent
            item.selected.titleTextAttributes = [
                .foregroundColor: accent,
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
            ]
        }
        style(appearance.stackedLayoutAppearance)
        style(appearance.inlineLayoutAppearance)
        style(appearance.compactInlineLayoutAppearance)

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        // Navigation bar 纸感：纸白底 + 近黑标题。
        // 滚到顶（内容未压在 Header 下）：无分隔线，对齐设计图静止态。
        let navScrollEdge = UINavigationBarAppearance()
        navScrollEdge.configureWithOpaqueBackground()
        navScrollEdge.backgroundColor = UIColor(named: "bg") ?? .white
        navScrollEdge.shadowColor = .clear
        navScrollEdge.titleTextAttributes = [.foregroundColor: UIColor(named: "fg") ?? .black]
        navScrollEdge.largeTitleTextAttributes = [.foregroundColor: UIColor(named: "fg") ?? .black]

        // 内容压在 Header 下：底部 1px border 分隔线（Header 底部边界线）。
        let navStandard = UINavigationBarAppearance()
        navStandard.configureWithOpaqueBackground()
        navStandard.backgroundColor = UIColor(named: "bg") ?? .white
        navStandard.shadowColor = UIColor(named: "border") ?? .lightGray
        navStandard.titleTextAttributes = [.foregroundColor: UIColor(named: "fg") ?? .black]
        navStandard.largeTitleTextAttributes = [.foregroundColor: UIColor(named: "fg") ?? .black]

        UINavigationBar.appearance().standardAppearance = navStandard
        UINavigationBar.appearance().scrollEdgeAppearance = navScrollEdge
        UINavigationBar.appearance().compactAppearance = navStandard
    }

    var body: some View {
        TabView {
            NavigationStack { WorkoutListView() }
                .tabItem { Label("训练", image: "tabTrain") }
            NavigationStack { PlanListView() }
                .tabItem { Label("计划", image: "tabPlan") }
            NavigationStack { ExerciseLibraryView() }
                .tabItem { Label("动作", image: "tabExercise") }
            NavigationStack { TeamListView() }
                .tabItem { Label("Team", image: "tabTeam") }
            NavigationStack { ProfileView() }
                .tabItem { Label("我的", image: "tabProfile") }
        }
        .tint(Theme.Color.accent)
        .toolbarBackground(Theme.Color.bg, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        // 休息全屏弹窗：挂在 TabView 之上的根层 overlay，层级天然高于 Tab Bar 与各页 Header，
        // 无需隐藏两栏；纯 .opacity 渐隐、无位移。
        .overlay {
            if restTimer.isExpanded {
                RestTimerSheet(controller: restTimer) {
                    withAnimation(restAnim) { restTimer.isExpanded = false }
                }
                .transition(.opacity)
            }
        }
        .onChange(of: restTimer.isRunning) { _, running in
            // 倒计时归零（或外部结束）时自动渐隐收回弹窗。
            if !running { withAnimation(restAnim) { restTimer.isExpanded = false } }
        }
    }
}

