import SwiftUI
import SwiftData
import UIKit

/// 主界面 Tab：训练三件套 + Team + 我的（饮食模块已移出 MVP）。
struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(RestTimerController.self) private var restTimer
    @Environment(PRCelebrationCenter.self) private var prCelebration
    @Environment(PlanWritebackCenter.self) private var planWriteback
    @Environment(TeamShareCenter.self) private var teamShare
    @Environment(TeamService.self) private var teamService
    @Environment(SyncEngine.self) private var syncEngine
    @Environment(SessionStore.self) private var session
    @Environment(WorkoutHistoryStore.self) private var historyStore
    @Environment(WorkoutPresentationCenter.self) private var workoutPresentation
    @Environment(WorkoutLiveActivityController.self) private var workoutLiveActivity
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 全局进行中会话（LIVE 悬浮胶囊来源）：未删除且未结束 = isActive。
    @State private var activeSession: Workout?
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
        case teamShare

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
        }
        .tint(Theme.Color.accent)
        .onAppear {
            refreshActiveSession()
            if PushManager.shared.pendingOpenedTeamId != nil {
                selectedTab = .team
            }
        }
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
        .onReceive(NotificationCenter.default.publisher(for: .dontliftActiveWorkoutChanged)) { _ in
            refreshActiveSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dontliftWorkoutSyncSucceeded)) { _ in
            Task { await retryReadyPendingShares() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dontliftTeamNudgeOpened)) { _ in
            selectedTab = .team
        }
        // 全局训练中悬浮窗/训练浮层：挂在 NavigationStack 之外，push 子页面上也可见；
        // 展开和收起都不改变当前 Tab 或导航层级。
        .overlay {
            WorkoutLiveOverlayContainer(activeSession: activeSession)
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
        // 根层弹窗队列：回写回执有撤销入口，优先展示；关闭后再展示 PR 庆祝与手动 Team 分享入口。
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
            case .teamShare:
                if let draft = teamShare.draft {
                    TeamShareSheet(draft: draft)
                }
            }
        }
        .onAppear { presentNextRootSheetIfNeeded() }
        .onChange(of: planWriteback.receipt != nil) { _, _ in presentNextRootSheetIfNeeded() }
        .onChange(of: prCelebration.records != nil) { _, _ in presentNextRootSheetIfNeeded() }
        .onChange(of: teamShare.draft != nil) { _, _ in presentNextRootSheetIfNeeded() }
        .onOpenURL { handleDeepLink($0) }
        .task(id: session.currentUserId) {
            if let userId = session.currentUserId {
                let hasPendingShare = !teamService.pendingShareWorkoutIds(userId: userId).isEmpty
                let hasPendingPlanEvent = teamService.hasPendingPlanShareEvents(userId: userId)
                if hasPendingShare || hasPendingPlanEvent {
                    await syncEngine.syncAll()
                }
            }
            await retryReadyPendingShares()
        }
    }

    private func presentNextRootSheetIfNeeded() {
        guard activeRootSheet == nil else { return }
        let next: RootSheet?
        if planWriteback.receipt != nil {
            next = .planWriteback
        } else if prCelebration.records != nil {
            next = .prCelebration
        } else if teamShare.draft != nil {
            next = .teamShare
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
            case .teamShare:
                teamShare.draft = nil
            }
        }
        presentedRootSheet = nil
        presentNextRootSheetIfNeeded()
    }

    private func refreshActiveSession() {
        activeSession = WorkoutSession.activeSession(in: modelContext)
        WorkoutWidgetSnapshotWriter.update(home: historyStore.home, activeWorkout: activeSession)
        workoutPresentation.reconcile(activeWorkout: activeSession)
        workoutLiveActivity.reconcile(activeWorkout: activeSession)
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "dontlift",
              url.host == "workout" else { return }
        selectedTab = .workout
        refreshActiveSession()
        if url.pathComponents.contains("live"), let activeSession {
            workoutPresentation.present(activeSession)
        }
    }

    private func retryReadyPendingShares() async {
        guard let userId = session.currentUserId else { return }
        let pendingIds = teamService.pendingShareWorkoutIds(userId: userId)
        let pendingEventWorkoutIds = teamService.pendingPlanShareEventWorkoutIds(userId: userId)
        let hasPendingEvents = teamService.hasPendingPlanShareEvents(userId: userId)
        guard !pendingIds.isEmpty || hasPendingEvents else { return }
        let workouts = (try? modelContext.fetch(FetchDescriptor<Workout>())) ?? []
        let syncedDrafts = Dictionary(uniqueKeysWithValues: workouts.compactMap { workout -> (UUID, TeamShareDraft)? in
            guard pendingIds.contains(workout.localId),
                  workout.deletedAt == nil,
                  workout.syncStatus == .synced else {
                return nil
            }
            return (workout.localId, TeamShareDraft(workout: workout))
        })
        if !syncedDrafts.isEmpty {
            await teamService.retryPendingShares(userId: userId, syncedDrafts: syncedDrafts)
        }
        if hasPendingEvents {
            let syncedWorkoutIds = Set(workouts.compactMap { workout -> UUID? in
                guard workout.deletedAt == nil,
                      workout.syncStatus == .synced,
                      (pendingEventWorkoutIds.isEmpty || pendingEventWorkoutIds.contains(workout.localId)) else {
                    return nil
                }
                return workout.localId
            })
            await teamService.retryPendingPlanShareEvents(userId: userId, syncedWorkoutIds: syncedWorkoutIds)
        }
    }
}
