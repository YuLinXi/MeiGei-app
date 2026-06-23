import SwiftUI
import SwiftData
import UIKit

/// 主界面 Tab：训练三件套 + Team + 我的（饮食模块已移出 MVP）。
struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(RestTimerController.self) private var restTimer
    @Environment(PRCelebrationCenter.self) private var prCelebration
    @Environment(PlanWritebackCenter.self) private var planWriteback
    @Environment(WorkoutHistoryStore.self) private var historyStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 全局进行中会话（LIVE 悬浮胶囊来源）：未删除且未结束 = isActive。
    @State private var activeSession: Workout?
    /// 全局胶囊点击 → push 进行中记录页（活跃会话必为 isActive，无需 finished 分流）。
    @State private var openedSession: Workout?
    @State private var activeRootSheet: RootSheet?
    @State private var presentedRootSheet: RootSheet?
    @State private var selectedTab: MainTab = .workout

    private enum MainTab: Hashable {
        case workout
        case plan
        case exercise
        case team
        case profile
    }

    private enum RootSheet: String, Identifiable {
        case planWriteback
        case prCelebration

        var id: String { rawValue }
    }

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
        // 全局唯一 NavigationStack 包 TabView：push 页渲染在 TabView（含 Tab Bar）之上，
        // 所有二级/三级页天然全屏、标准右滑入转场，Tab Bar 被盖住而非做消失动画。
        NavigationStack {
            TabView(selection: $selectedTab) {
                WorkoutListView()
                    .tabItem { Label("训练", image: "tabTrain") }
                    .tag(MainTab.workout)
                PlanListView()
                    .tabItem { Label("计划", image: "tabPlan") }
                    .tag(MainTab.plan)
                ExerciseLibraryView()
                    .tabItem { Label("动作", image: "tabExercise") }
                    .tag(MainTab.exercise)
                TeamListView()
                    .tabItem { Label("Team", image: "tabTeam") }
                    .tag(MainTab.team)
                ProfileView()
                    .tabItem { Label("我的", image: "tabProfile") }
                    .tag(MainTab.profile)
            }
            .toolbarBackground(Theme.Color.bg, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            // 全局 LIVE 悬浮胶囊：有进行中会话时浮于 TabView 之上、各 Tab 通用；
            // 挂在 NavigationStack 内 → push 进 Live 记录页时被全屏页自然盖住。
            .overlay {
                if let active = activeSession {
                    LiveSessionCapsule(title: active.title ?? "训练") {
                        openedSession = active
                    }
                }
            }
            // 全局胶囊点击 → 绑定式导航进 Live 记录页（与各 Tab 内部的 openedSession 各自独立）。
            .navigationDestination(item: $openedSession) { WorkoutLoggingView(workout: $0) }
        }
        .tint(Theme.Color.accent)
        .onAppear { refreshActiveSession() }
        .onChange(of: selectedTab) { _, tab in
            if tab == .workout {
                WorkoutPerformanceMonitor.event("home.tab.selected")
                refreshActiveSession()
            }
        }
        .onChange(of: historyStore.lastRefreshFinishedAt) { _, _ in
            refreshActiveSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dontliftSyncCompleted)) { _ in
            refreshActiveSession()
        }
        // 休息全屏弹窗：挂在全局 NavigationStack 之上的 overlay，层级高于 push 页与 Tab Bar；
        // 纯 .opacity 渐隐、无位移。
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
        // 根层弹窗队列：回写回执有撤销入口，优先展示；关闭后再展示 PR 庆祝。
        .sheet(item: $activeRootSheet, onDismiss: clearPresentedRootSheetAndContinue) { sheet in
            switch sheet {
            case .planWriteback:
                if let receipt = planWriteback.receipt {
                    PlanWritebackSheet(receipt: receipt)
                }
            case .prCelebration:
                if let records = prCelebration.records {
                    PRCelebrationSheet(records: records, summary: prCelebration.summary)
                }
            }
        }
        .onAppear { presentNextRootSheetIfNeeded() }
        .onChange(of: planWriteback.receipt != nil) { _, _ in presentNextRootSheetIfNeeded() }
        .onChange(of: prCelebration.records != nil) { _, _ in presentNextRootSheetIfNeeded() }
    }

    private func presentNextRootSheetIfNeeded() {
        guard activeRootSheet == nil else { return }
        let next: RootSheet?
        if planWriteback.receipt != nil {
            next = .planWriteback
        } else if prCelebration.records != nil {
            next = .prCelebration
        } else {
            next = nil
        }
        guard let next else { return }
        activeRootSheet = next
        presentedRootSheet = next
    }

    private func clearPresentedRootSheetAndContinue() {
        if let presentedRootSheet {
            switch presentedRootSheet {
            case .planWriteback:
                planWriteback.receipt = nil
            case .prCelebration:
                prCelebration.records = nil
            }
        }
        presentedRootSheet = nil
        presentNextRootSheetIfNeeded()
    }

    private func refreshActiveSession() {
        activeSession = WorkoutSession.activeSession(in: modelContext)
    }
}
