import SwiftUI
import SwiftData
import HealthKit

// MARK: - 个人中心（Screen 11，Neon 改版）

struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @Environment(SyncEngine.self) private var syncEngine
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(RestTimerController.self) private var restTimer

    @Query private var profiles: [UserProfile]
    @Query(filter: #Predicate<Workout> { $0.deletedAt == nil && $0.endedAt != nil })
    private var workouts: [Workout]

    @State private var confirmLogout = false
    @State private var confirmDelete = false
    @State private var versionTapCount = 0
    @State private var showDesignSystem = false

    // 删号流程态
    @State private var deletionImpact: DeletionImpactDTO?
    @State private var loadingImpact = false
    @State private var deleting = false
    @State private var deleteError: String?

    // 法律页 / HealthKit / 通知态
    @State private var legalURL: IdentifiableURL?
    @State private var healthAuthorized = false
    @State private var notificationsEnabled: Bool?

    private var profile: UserProfile? { profiles.first(where: { $0.serverUserId == session.currentUserId }) }

    private var totalWorkouts: Int { workouts.count }

    /// 最长连续训练天数（不要求每日，按日去重连贯计）。
    private var longestStreak: Int {
        let cal = Calendar.current
        let days = Set(workouts.map { cal.startOfDay(for: $0.startedAt) })
        let sorted = days.sorted()
        var best = 0
        var cur = 0
        var prev: Date?
        for d in sorted {
            if let p = prev, cal.date(byAdding: .day, value: 1, to: p) == d {
                cur += 1
            } else {
                cur = 1
            }
            best = max(best, cur)
            prev = d
        }
        return best
    }

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                pageTitle
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        header
                        statsGrid
                        syncGroup
                        trainingPrefsGroup
                        aboutGroup
                        accountGroup
                        Color.clear.frame(height: 32)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
                }
            }
        }
        // 自绘大标题头（对齐其它 Tab 根页范式 A），隐藏系统导航栏。
        .toolbar(.hidden, for: .navigationBar)
        .task {
            healthAuthorized = healthKit.isAuthorized
            await refreshNotificationStatus()
        }
        .safariSheet(url: $legalURL)
        .paperConfirmDialog(
            isPresented: $confirmLogout,
            title: "退出登录?",
            message: "本地数据保留,下次登录后继续同步。",
            confirmTitle: "退出登录",
            onConfirm: { session.logout() }
        )
        .paperConfirmDialog(
            isPresented: $confirmDelete,
            title: "删除账号?",
            message: deleteConfirmMessage,
            confirmTitle: "删除账号",
            onConfirm: { performDelete() }
        )
        .alert("删除失败", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
        #if DEBUG
        // DEBUG-only 开发工具页：用自带 NavigationStack 的 fullScreenCover 独立呈现，
        // 而非挂在「全局 NavigationStack 包 TabView」的栈上 —— 后者会让 navigationDestination
        // 从 TabView 子页注册时被判定为「misplaced / 将被忽略」(Xcode 运行时告警)。
        .fullScreenCover(isPresented: $showDesignSystem) {
            NavigationStack {
                DesignSystemPreviewView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("关闭") { showDesignSystem = false }
                                .tint(Theme.Color.accent)
                        }
                    }
            }
        }
        #endif
    }

    // MARK: - Header

    // 大标题头（对齐设计稿 .nav，与其它 Tab 根页一致）。
    private var pageTitle: some View {
        HStack {
            Text("我的")
                .font(Theme.Font.display(size: 36, weight: .heavy))
                .tracking(-1.08)
                .foregroundStyle(Theme.Color.fg)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var header: some View {
        let name = profile?.displayName ?? "已登录"
        let years = trainingYears()
        return HStack(spacing: Theme.Spacing.md) {
            avatarCircle(initial: String(name.prefix(1)))
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(Theme.Font.display(size: 22, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                Text(subtitleText(years: years))
                    .font(Theme.Font.mono(size: 12))
                    .foregroundStyle(Theme.Color.muted)
            }
            Spacer()
        }
    }

    private func avatarCircle(initial: String) -> some View {
        let color = ProfileView.avatarPalette[abs(initial.hashValue) % ProfileView.avatarPalette.count]
        return ZStack {
            Circle().fill(color).frame(width: 64, height: 64)
            Text(initial)
                .font(Theme.Font.display(size: 28, weight: .bold))
                .foregroundStyle(Theme.Color.bg)
        }
    }

    private static let avatarPalette: [Color] = [
        Theme.Color.accent,
        Theme.Color.accent,
        Theme.Color.ok,
    ]

    private func subtitleText(years: Double) -> String {
        "训练龄 \(String(format: "%.1f", years)) 年"
    }

    private func trainingYears() -> Double {
        guard let earliest = workouts.map(\.startedAt).min() else { return 0 }
        let secs = Date().timeIntervalSince(earliest)
        return max(0, secs / (365.25 * 86_400))
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 0) {
            statCell(title: "总训练", value: "\(totalWorkouts)", tint: Theme.Color.fg)
            statDivider
            statCell(title: "最长连续", value: "\(longestStreak)", tint: Theme.Color.fg)
        }
        .cardStyle(padding: 0)
    }

    private func statCell(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Text(value).numStyle(size: 22, weight: .bold).foregroundStyle(tint)
            Text(title).eyebrowStyle()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
    }

    private var statDivider: some View {
        Rectangle().fill(Theme.Color.border).frame(width: 1)
    }

    // MARK: - 数据 · 同步

    private var syncGroup: some View {
        groupCard(title: "数据 · 同步") {
            healthKitRow
            rowDivider
            SyncRow(syncEngine: syncEngine)
        }
    }

    /// HealthKit 行：未授权时可点击发起授权，授权态实时刷新。
    private var healthKitRow: some View {
        let available = HKHealthStore.isHealthDataAvailable()
        return HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "heart.text.square")
                .foregroundStyle(Theme.Color.fg2)
                .frame(width: 24)
            Text("HealthKit")
                .font(Theme.Font.body(size: 14))
                .foregroundStyle(Theme.Color.fg)
            Spacer()
            Text(healthAuthorized ? "已连接" : (available ? "未授权" : "不可用"))
                .font(Theme.Font.mono(size: 12))
                .foregroundStyle(healthAuthorized ? Theme.Color.ok : Theme.Color.danger)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: 48)
        .contentShape(Rectangle())
        .onTapGesture {
            guard available, !healthAuthorized else { return }
            Task {
                await healthKit.requestAuthorization()
                healthAuthorized = healthKit.isAuthorized
            }
        }
    }

    // MARK: - 训练偏好

    private var trainingPrefsGroup: some View {
        @Bindable var restTimer = restTimer
        return groupCard(title: "训练偏好") {
            // 默认休息时长
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "timer").foregroundStyle(Theme.Color.fg2).frame(width: 24)
                Text("默认休息时长")
                    .font(Theme.Font.body(size: 14))
                    .foregroundStyle(Theme.Color.fg)
                Spacer()
                durationStepper(value: $restTimer.defaultDuration)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .frame(height: 48)

            rowDivider

            // 震动开关
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "iphone.radiowaves.left.and.right").foregroundStyle(Theme.Color.fg2).frame(width: 24)
                Text("震动")
                    .font(Theme.Font.body(size: 14))
                    .foregroundStyle(Theme.Color.fg)
                Spacer()
                Toggle("", isOn: $restTimer.hapticsEnabled)
                    .labelsHidden()
                    .tint(Theme.Color.accent)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .frame(height: 48)

            rowDivider

            // 通知（展示系统授权态 + 跳系统设置）
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "bell").foregroundStyle(Theme.Color.fg2).frame(width: 24)
                Text("通知")
                    .font(Theme.Font.body(size: 14))
                    .foregroundStyle(Theme.Color.fg)
                Spacer()
                Text(notificationStatusText)
                    .font(Theme.Font.mono(size: 12))
                    .foregroundStyle(notificationsEnabled == true ? Theme.Color.ok : Theme.Color.muted)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Color.muted)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .frame(height: 48)
            .contentShape(Rectangle())
            .onTapGesture { openSystemSettings() }
        }
    }

    /// 休息时长加减器（步进 15s，范围 15…600s）。
    private func durationStepper(value: Binding<TimeInterval>) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            stepperButton("minus") {
                value.wrappedValue = max(15, value.wrappedValue - 15)
            }
            Text("\(Int(value.wrappedValue))s")
                .font(Theme.Font.mono(size: 13))
                .foregroundStyle(Theme.Color.fg)
                .frame(minWidth: 44)
            stepperButton("plus") {
                value.wrappedValue = min(600, value.wrappedValue + 15)
            }
        }
    }

    private func stepperButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.Color.accent)
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(Theme.Color.accentSofter, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private var notificationStatusText: String {
        switch notificationsEnabled {
        case .some(true): return "已开启"
        case .some(false): return "未开启"
        case .none: return "—"
        }
    }

    // MARK: - 关于

    private var aboutGroup: some View {
        groupCard(title: "关于") {
            HStack {
                Image(systemName: "info.circle").foregroundStyle(Theme.Color.fg2).frame(width: 24)
                Text("版本")
                    .font(Theme.Font.body(size: 14))
                    .foregroundStyle(Theme.Color.fg)
                Spacer()
                Text(appVersion)
                    .font(Theme.Font.mono(size: 12))
                    .foregroundStyle(Theme.Color.muted)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .frame(height: 48)
            .contentShape(Rectangle())
            .onTapGesture { handleVersionTap() }

            rowDivider
            legalRow(icon: "hand.raised", title: "隐私政策", url: AppConfig.privacyPolicyURL)
            rowDivider
            legalRow(icon: "doc.text", title: "服务条款", url: AppConfig.termsOfServiceURL)
        }
    }

    private func legalRow(icon: String, title: String, url: URL) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon).foregroundStyle(Theme.Color.fg2).frame(width: 24)
            Text(title)
                .font(Theme.Font.body(size: 14))
                .foregroundStyle(Theme.Color.fg)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Color.muted)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: 48)
        .contentShape(Rectangle())
        .onTapGesture { legalURL = IdentifiableURL(url: url) }
    }

    // MARK: - 账号

    private var accountGroup: some View {
        groupCard(title: "账号") {
            // 退出登录
            Button { confirmLogout = true } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(Theme.Color.danger).frame(width: 24)
                    Text("退出登录")
                        .font(Theme.Font.body(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Color.danger)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.md)
                .frame(height: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            rowDivider

            // 删除账号（danger，先拉影响面再二次确认）
            Button { startDelete() } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "trash")
                        .foregroundStyle(Theme.Color.danger).frame(width: 24)
                    Text("删除账号")
                        .font(Theme.Font.body(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Color.danger)
                    Spacer()
                    if loadingImpact || deleting {
                        ProgressView().tint(Theme.Color.danger)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .frame(height: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(loadingImpact || deleting)
        }
    }

    // MARK: - 删号流程

    /// 二次确认文案：强调不可恢复，并显式列出影响面（若已成功拉取）。
    private var deleteConfirmMessage: String {
        var lines = "账号与全部训练数据将被永久删除,不可恢复。"
        if let impact = deletionImpact, impact.ownedTeams > 0 {
            lines += "\n将解散 \(impact.ownedTeams) 个团队、影响 \(impact.affectedMembers) 名成员。"
        }
        return lines
    }

    private func startDelete() {
        guard !loadingImpact, !deleting else { return }
        loadingImpact = true
        Task {
            // 影响面拉取失败不阻断删除（确认框退化为通用文案）
            deletionImpact = try? await AccountAPI.deletionImpact()
            loadingImpact = false
            confirmDelete = true
        }
    }

    private func performDelete() {
        guard !deleting else { return }
        deleting = true
        Task {
            do {
                try await AccountAPI.deleteAccount()
                // 成功：清本地 + 登出 → RootView 监听 isLoggedIn 自动回 LoginView
                session.wipeLocalDataAndLogout()
                // 视图随登出销毁，无需复位 deleting
            } catch {
                deleteError = (error as? APIError)?.errorDescription ?? error.localizedDescription
                deleting = false
            }
        }
    }

    // MARK: - 通用辅助

    @ViewBuilder
    private func groupCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title).eyebrowStyle()
            VStack(spacing: 0) { content() }
                .cardStyle(padding: 0)
        }
    }

    private var rowDivider: some View {
        Rectangle().fill(Theme.Color.border).frame(height: 1).padding(.leading, 48)
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

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsEnabled = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
    }
}

// MARK: - 同步行（带 SyncEngine 状态）

struct SyncRow: View {
    let syncEngine: SyncEngine

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(Theme.Color.fg2)
                .frame(width: 24)
            Text("立即同步")
                .font(Theme.Font.body(size: 14))
                .foregroundStyle(Theme.Color.fg)
            Spacer()
            if syncEngine.isSyncing {
                ProgressView().tint(Theme.Color.accent)
                Text("同步中…")
                    .font(Theme.Font.mono(size: 11))
                    .foregroundStyle(Theme.Color.fg2)
            } else {
                Text("空闲")
                    .font(Theme.Font.mono(size: 11))
                    .foregroundStyle(Theme.Color.muted)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: 48)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !syncEngine.isSyncing else { return }
            Task { await syncEngine.syncAll() }
        }
    }
}
