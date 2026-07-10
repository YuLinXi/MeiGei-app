import SwiftUI
import SwiftData
import HealthKit

// MARK: - 个人中心（Screen 11，Neon 改版）

struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @Environment(SyncEngine.self) private var syncEngine
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(RestTimerController.self) private var restTimer
    @Environment(WorkoutHistoryStore.self) private var historyStore
    @Environment(\.modelContext) private var modelContext

    @Query private var profiles: [UserProfile]

    @State private var confirmLogout = false
    @State private var confirmDelete = false
    @State private var versionTapCount = 0
    @State private var showDesignSystem = false

    // 称呼行内编辑态
    @State private var editingName = false
    @State private var nameDraft = ""
    @FocusState private var nameFieldFocused: Bool

    // 删号流程态
    @State private var deletionImpact: DeletionImpactDTO?
    @State private var loadingImpact = false
    @State private var deleting = false
    @State private var deleteError: String?

    // Sheet / HealthKit / 通知态
    @State private var profileSheet: ProfileSheet?
    @State private var healthAuthorized = false
    @State private var notificationsEnabled: Bool?
    @State private var caloriePreferences = WorkoutCaloriePreferences.current()

    private var profile: UserProfile? { profiles.first(where: { $0.serverUserId == session.currentUserId }) }

    private var totalWorkouts: Int { historyStore.profile.totalWorkouts }

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        header
                        personalInfoGroup
                        syncGroup
                        trainingPrefsGroup
                        aboutGroup
                        accountGroup
                        deleteAccountRow
                        Color.clear.frame(height: 32)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
                }
            }
        }
        .rootTabTopScrim()
        // 我的页不展示顶部标题，隐藏系统导航栏。
        .toolbar(.hidden, for: .navigationBar)
        .task {
            WorkoutPerformanceMonitor.event("profile.appear")
            healthAuthorized = healthKit.isAuthorized
            caloriePreferences = .current()
            await refreshNotificationStatus()
        }
        .sheet(item: $profileSheet) { sheet in
            profileSheetView(sheet)
        }
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

    private var header: some View {
        let name = profile?.displayName ?? "已登录"
        return HStack(spacing: Theme.Spacing.md) {
            avatarCircle(initial: String(name.prefix(1)))
            VStack(alignment: .leading, spacing: 4) {
                // 顶部称呼纯展示，不在此编辑——编辑统一进「个人资料」组。
                Text(name)
                    .font(Theme.Font.display(size: 22, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                Text(headerSubtitle)
                    .font(Theme.Font.mono(size: 12))
                    .foregroundStyle(Theme.Color.muted)
            }
            Spacer()
        }
    }

    private func avatarCircle(initial: String) -> some View {
        // 头像统一用主色调（朱砂红），与全局单点强调一致。
        ZStack {
            Circle().fill(Theme.Color.accent).frame(width: 64, height: 64)
            Text(initial)
                .font(Theme.Font.display(size: 28, weight: .bold))
                .foregroundStyle(Theme.Color.bg)
        }
    }

    /// 副标：只展示总训练次数。
    private var headerSubtitle: String {
        "总训练次数 \(totalWorkouts) 次"
    }

    // MARK: - 个人资料分组（称呼可编辑 + 性别，均为资料、改即 PATCH 后端）

    private var personalInfoGroup: some View {
        groupCard(title: "个人资料") {
            nameRow
            rowDivider
            sexRow
        }
    }

    /// 称呼：点击进入行内编辑（输入框 + 保存/取消，1–20 字）；保存乐观本地写 + PATCH。
    @ViewBuilder
    private var nameRow: some View {
        if editingName {
            nameEditingRow
        } else {
            nameDisplayRow
        }
    }

    private var nameDisplayRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "person")
                .foregroundStyle(Theme.Color.fg2)
                .frame(width: 24)
            Text("称呼")
                .font(Theme.Font.body(size: 14))
                .foregroundStyle(Theme.Color.fg)
            Spacer()
            Text(profile?.displayName ?? "未设置")
                .font(Theme.Font.body(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Color.muted)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: 48)
        .contentShape(Rectangle())
        .onTapGesture { beginEditName() }
    }

    private var nameEditingRow: some View {
        let draft = nameDraft.trimmingCharacters(in: .whitespaces)
        let valid = !draft.isEmpty && draft.count <= 20
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "person")
                    .foregroundStyle(Theme.Color.accent)
                    .frame(width: 24)
                TextField("称呼", text: $nameDraft)
                    .font(Theme.Font.body(size: 15))
                    .foregroundStyle(Theme.Color.fg)
                    .focused($nameFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { if valid { saveName() } }
            }
            HStack {
                Text(draft.count > 20 ? "称呼不超过 20 字" : "1–20 字")
                    .font(Theme.Font.mono(size: 10))
                    .foregroundStyle(draft.count > 20 ? Theme.Color.danger : Theme.Color.muted)
                Spacer()
                Button("取消") { cancelEditName() }
                    .font(Theme.Font.body(size: 13))
                    .foregroundStyle(Theme.Color.fg2)
                Button("保存") { saveName() }
                    .font(Theme.Font.body(size: 13, weight: .semibold))
                    .foregroundStyle(valid ? Theme.Color.accent : Theme.Color.muted)
                    .disabled(!valid)
            }
            .padding(.leading, 24 + Theme.Spacing.md)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 10)
    }

    private var sexRow: some View {
        let current = profile?.sex ?? .male
        return HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "figure.stand")
                .foregroundStyle(Theme.Color.fg2)
                .frame(width: 24)
            Text("性别")
                .font(Theme.Font.body(size: 14))
                .foregroundStyle(Theme.Color.fg)
            Spacer()
            HStack(spacing: 6) {
                ForEach(BodySex.allCases) { s in
                    sexPill(s, selected: current == s)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: 48)
    }

    private func sexPill(_ s: BodySex, selected: Bool) -> some View {
        Text(s.displayName)
            .font(Theme.Font.body(size: 13, weight: selected ? .semibold : .regular))
            .foregroundStyle(selected ? Color.white : Theme.Color.fg2)
            .frame(width: 40, height: 28)
            .background(selected ? Theme.Color.accent : Theme.Color.surface2,
                        in: Capsule())
            .overlay(Capsule().stroke(selected ? Color.clear : Theme.Color.border, lineWidth: 1))
            .contentShape(Capsule())
            .onTapGesture { setSex(s) }
    }

    private func beginEditName() {
        nameDraft = profile?.displayName ?? ""
        editingName = true
        nameFieldFocused = true
    }

    private func cancelEditName() {
        editingName = false
        nameFieldFocused = false
    }

    /// 保存称呼：乐观本地写 + PATCH 上行（失败静默重试）。
    private func saveName() {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count <= 20, let profile = session.ensureProfile() else { return }
        profile.displayName = trimmed
        try? modelContext.save()
        session.scheduleProfilePush()
        Theme.Haptics.selection()
        editingName = false
        nameFieldFocused = false
    }

    /// 切换性别：资料字段，乐观本地写 + PATCH 上行（驱动肌群图 + 回灌后端）。
    private func setSex(_ s: BodySex) {
        // 用 ensureProfile 兜底：desync 场景下（token 在、本地档案缺失）@Query 查不到 profile，
        // 此处补建后再写，避免点击性别胶囊静默无效。
        guard let profile = session.ensureProfile(), profile.sex != s else { return }
        profile.sex = s
        try? modelContext.save()
        session.scheduleProfilePush()
        Theme.Haptics.selection()
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
        groupCard(title: "训练偏好") {
            defaultRestDurationRow

            rowDivider

            calorieEstimateToggleRow

            rowDivider

            calorieBodyWeightRow

            rowDivider

            // 震动开关
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "iphone.radiowaves.left.and.right").foregroundStyle(Theme.Color.fg2).frame(width: 24)
                Text("震动")
                    .font(Theme.Font.body(size: 14))
                    .foregroundStyle(Theme.Color.fg)
                Spacer()
                Toggle("", isOn: restTimerHapticsBinding)
                    .labelsHidden()
                    .tint(Theme.Color.accent)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .frame(height: 48)

            rowDivider

            // 声音开关：统一控制前台 App 内音效与后台/锁屏本地通知音。
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "speaker.wave.2").foregroundStyle(Theme.Color.fg2).frame(width: 24)
                Text("声音")
                    .font(Theme.Font.body(size: 14))
                    .foregroundStyle(Theme.Color.fg)
                Spacer()
                Toggle("", isOn: restTimerSoundBinding)
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

    private var defaultRestDurationRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "timer").foregroundStyle(Theme.Color.fg2).frame(width: 24)
            Text("默认休息时长")
                .font(Theme.Font.body(size: 14))
                .foregroundStyle(Theme.Color.fg)
            Spacer()
            Text(profileRestDurationText(restTimer.defaultDuration))
                .font(Theme.Font.mono(size: 12))
                .foregroundStyle(Theme.Color.fg)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Color.muted)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: 48)
        .contentShape(Rectangle())
        .onTapGesture { profileSheet = .restDuration }
    }

    private var restTimerHapticsBinding: Binding<Bool> {
        Binding(
            get: { restTimer.hapticsEnabled },
            set: { restTimer.hapticsEnabled = $0 }
        )
    }

    private var restTimerSoundBinding: Binding<Bool> {
        Binding(
            get: { restTimer.soundEnabled },
            set: { restTimer.soundEnabled = $0 }
        )
    }

    private var calorieEstimateEnabledBinding: Binding<Bool> {
        Binding(
            get: { calorieEstimatesEnabled },
            set: {
                setCalorieEstimatesEnabled($0)
            }
        )
    }

    private var calorieEstimatesEnabled: Bool {
        caloriePreferences.showsEstimates && caloriePreferences.bodyWeightKg != nil
    }

    private var calorieEstimateToggleRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "flame")
                .foregroundStyle(Theme.Color.fg2)
                .frame(width: 24)
            Text("消耗估算")
                .font(Theme.Font.body(size: 14))
                .foregroundStyle(Theme.Color.fg)
            Spacer()
            Toggle("", isOn: calorieEstimateEnabledBinding)
                .labelsHidden()
                .tint(Theme.Color.accent)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: 48)
    }

    private var calorieBodyWeightRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "scalemass")
                .foregroundStyle(Theme.Color.fg2)
                .frame(width: 24)
            Text("估算体重")
                .font(Theme.Font.body(size: 14))
                .foregroundStyle(Theme.Color.fg)
            Spacer()
            Text(calorieBodyWeightText)
                .font(Theme.Font.mono(size: 12))
                .foregroundStyle(calorieBodyWeightColor)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Color.muted)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: 48)
        .contentShape(Rectangle())
        .onTapGesture {
            profileSheet = .calorieWeight(enableAfterSave: caloriePreferences.showsEstimates)
        }
    }

    private var calorieBodyWeightText: String {
        guard let kg = caloriePreferences.bodyWeightKg else {
            return caloriePreferences.showsEstimates ? "必填" : "未设置"
        }
        return "\(formatKg(kg))kg"
    }

    private var calorieBodyWeightColor: Color {
        caloriePreferences.bodyWeightKg == nil && caloriePreferences.showsEstimates
            ? Theme.Color.danger
            : Theme.Color.fg
    }

    private func setCalorieEstimatesEnabled(_ enabled: Bool) {
        if enabled, caloriePreferences.bodyWeightKg == nil {
            profileSheet = .calorieWeight(enableAfterSave: true)
            return
        }
        WorkoutCaloriePreferences.setShowsEstimates(enabled)
        caloriePreferences = WorkoutCaloriePreferences.current()
    }

    private func saveCalorieBodyWeight(_ kg: Double, enableAfterSave: Bool) {
        WorkoutCaloriePreferences.setBodyWeightKg(kg)
        if enableAfterSave {
            WorkoutCaloriePreferences.setShowsEstimates(true)
        }
        caloriePreferences = WorkoutCaloriePreferences.current()
        Theme.Haptics.selection()
    }

    @ViewBuilder
    private func profileSheetView(_ sheet: ProfileSheet) -> some View {
        switch sheet {
        case .legal(let url):
            SafariView(url: url)
                .ignoresSafeArea()
        case .calorieWeight(let enableAfterSave):
            CalorieBodyWeightSheet(
                currentWeight: caloriePreferences.bodyWeightKg,
                enableAfterSave: enableAfterSave,
                onSave: saveCalorieBodyWeight
            )
        case .restDuration:
            RestDurationEditorSheet(initialDuration: restTimer.defaultDuration) {
                restTimer.defaultDuration = $0
                Theme.Haptics.selection()
            }
        }
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
        .onTapGesture { profileSheet = .legal(url) }
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
        }
    }

    /// 删除账号（极弱化入口：无卡片背景、muted 小字、右对齐、无图标；
    /// 红色危险感仅留在二次确认弹窗。先拉影响面再二次确认）
    private var deleteAccountRow: some View {
        HStack(spacing: 0) {
            Spacer()
            // 仅文字区域可点：Spacer 在 Button 外，按钮只包住文案本身
            Button { startDelete() } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Text("删除账号")
                        .font(Theme.Font.body(size: 11))
                        .foregroundStyle(Theme.Color.muted)
                    if loadingImpact || deleting {
                        ProgressView().tint(Theme.Color.muted)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(loadingImpact || deleting)
        }
    }

    // MARK: - 删号流程

    /// 二次确认文案：强调不可恢复，并显式列出影响面（若已成功拉取）。
    private var deleteConfirmMessage: String {
        var lines = "账号与本人训练数据将被永久删除,不可恢复。"
        if let impact = deletionImpact {
            if impact.ownedTeamsToTransfer > 0 {
                lines += "\n\(impact.ownedTeamsToTransfer) 个多人 Team 将保留，并自动转移队长；其他成员历史不会被删除。"
            }
            if impact.emptyOwnedTeamsToDelete > 0 {
                lines += "\n\(impact.emptyOwnedTeamsToDelete) 个只有你的空 Team 将被删除。"
            }
            if impact.affectedMembers > 0 {
                lines += "\n涉及 \(impact.affectedMembers) 名成员的 Team 共享历史将继续保留。"
            }
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

private enum ProfileSheet: Identifiable {
    case legal(URL)
    case calorieWeight(enableAfterSave: Bool)
    case restDuration

    var id: String {
        switch self {
        case .legal(let url): return "legal:\(url.absoluteString)"
        case .calorieWeight(let enableAfterSave): return enableAfterSave ? "calorieWeight.enable" : "calorieWeight.edit"
        case .restDuration: return "restDuration"
        }
    }
}

private struct CalorieBodyWeightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var weightFocused: Bool

    let enableAfterSave: Bool
    let onSave: (Double, Bool) -> Void

    @State private var weightText: String

    init(currentWeight: Double?, enableAfterSave: Bool, onSave: @escaping (Double, Bool) -> Void) {
        self.enableAfterSave = enableAfterSave
        self.onSave = onSave
        _weightText = State(initialValue: currentWeight.map(formatKg) ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            PaperSheetHeader(
                title: enableAfterSave ? "开启消耗估算" : "估算体重",
                cancelTitle: "取消",
                confirmTitle: "完成",
                confirmEnabled: parsedWeight != nil,
                background: Theme.Color.bg,
                onCancel: { dismiss() },
                onConfirm: save
            )

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("体重")
                    .eyebrowStyle()

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("30–250", text: $weightText)
                        .font(Theme.Font.number(size: 30, weight: .bold))
                        .foregroundStyle(Theme.Color.fg)
                        .keyboardType(.decimalPad)
                        .focused($weightFocused)
                    Text("kg")
                        .font(Theme.Font.body(size: 14, weight: .bold))
                        .foregroundStyle(Theme.Color.muted)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .frame(height: 68)
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .stroke(inputBorderColor, lineWidth: 1)
                )

                Text(helperText)
                    .font(Theme.Font.mono(size: 11))
                    .foregroundStyle(helperColor)
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Theme.Color.bg.ignoresSafeArea())
        .presentationBackground(Theme.Color.bg)
        .presentationDetents([.height(260), .medium])
        .onAppear { weightFocused = true }
    }

    private var parsedWeight: Double? {
        let text = weightText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(text) else { return nil }
        return WorkoutCaloriePreferences.normalizedBodyWeight(value)
    }

    private var inputBorderColor: Color {
        weightText.isEmpty || parsedWeight != nil ? Theme.Color.border : Theme.Color.danger
    }

    private var helperText: String {
        if weightText.isEmpty {
            return enableAfterSave ? "开启前必须填写体重" : "范围 30–250 kg"
        }
        return parsedWeight == nil ? "请输入 30–250 kg" : "仅用于本机 kcal 估算"
    }

    private var helperColor: Color {
        !weightText.isEmpty && parsedWeight == nil ? Theme.Color.danger : Theme.Color.muted
    }

    private func save() {
        guard let parsedWeight else { return }
        onSave(parsedWeight, enableAfterSave)
        dismiss()
    }
}

private struct RestDurationEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: DurationField?

    let onSave: (TimeInterval) -> Void

    @State private var minuteText: String
    @State private var secondText: String

    init(initialDuration: TimeInterval, onSave: @escaping (TimeInterval) -> Void) {
        self.onSave = onSave
        let parts = Self.durationParts(initialDuration)
        _minuteText = State(initialValue: "\(parts.minutes)")
        _secondText = State(initialValue: "\(parts.seconds)")
    }

    var body: some View {
        VStack(spacing: 0) {
            PaperSheetHeader(
                title: "默认休息时长",
                cancelTitle: "取消",
                confirmTitle: "完成",
                confirmEnabled: parsedDuration != nil,
                background: Theme.Color.bg,
                onCancel: { dismiss() },
                onConfirm: save
            )

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("时长")
                    .font(Theme.Font.body(size: 16, weight: .bold))
                    .foregroundStyle(Theme.Color.fg2)

                VStack(spacing: Theme.Spacing.md) {
                    HStack(spacing: Theme.Spacing.sm) {
                        durationField(title: "分钟", text: $minuteText, field: .minutes)
                        durationField(title: "秒", text: $secondText, field: .seconds)
                    }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .stroke(Theme.Color.border, lineWidth: 1)
                )
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Theme.Color.bg.ignoresSafeArea())
        .presentationBackground(Theme.Color.bg)
        .presentationDetents([.height(260), .medium])
        .onAppear { focusedField = .minutes }
    }

    private func save() {
        guard let parsedDuration else { return }
        onSave(parsedDuration)
        dismiss()
    }

    private var parsedDuration: TimeInterval? {
        guard let minutes = parsedNumber(minuteText),
              let seconds = parsedNumber(secondText),
              seconds <= 59
        else { return nil }

        let total = minutes * 60 + seconds
        guard total >= 15, total <= 600 else { return nil }
        return TimeInterval(total)
    }

    private func parsedNumber(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        guard trimmed.allSatisfy(\.isNumber) else { return nil }
        return Int(trimmed)
    }

    private func durationField(title: String, text: Binding<String>, field: DurationField) -> some View {
        ZStack(alignment: .bottomTrailing) {
            TextField("0", text: text)
                .font(Theme.Font.number(size: 28, weight: .bold))
                .foregroundStyle(Theme.Color.fg)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .focused($focusedField, equals: field)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, 12)
            Text(title)
                .font(Theme.Font.body(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Color.muted)
                .padding(.trailing, 12)
                .padding(.bottom, 9)
        }
        .frame(height: 68)
        .background(Theme.Color.bg, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .stroke(Theme.Color.border, lineWidth: 1)
        )
    }

    private static func durationParts(_ value: TimeInterval) -> (minutes: Int, seconds: Int) {
        let seconds = Int(min(600, max(15, value)).rounded())
        return (seconds / 60, seconds % 60)
    }

    private enum DurationField: Hashable {
        case minutes
        case seconds
    }
}

private func profileRestDurationText(_ duration: TimeInterval) -> String {
    let seconds = Int(duration.rounded())
    if seconds >= 60 {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return remainder == 0 ? "\(minutes) 分钟" : "\(minutes) 分 \(remainder) 秒"
    }
    return "\(seconds) 秒"
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
