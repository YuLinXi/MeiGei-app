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
    @Environment(BadgeWallStore.self) private var badgeWallStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title2) private var avatarDiameter: CGFloat = 64

    @Query private var profiles: [UserProfile]

    @State private var confirmLogout = false
    @State private var confirmDelete = false
    @State private var versionTapCount = 0
    @State private var showDesignSystem = false
    #if DEBUG
    /// 演示数据生成结果提示（仅 DEBUG）。
    @State private var seedResult: String?
    #endif

    // 称呼行内编辑态
    @State private var editingName = false
    @State private var nameDraft = ""
    @FocusState private var nameFieldFocused: Bool
    @State private var profileSaveFailure: ProfileSaveFailure?

    private enum ProfileSaveFailure: Equatable {
        case name
        case sex(BodySex)

        var message: String {
            switch self {
            case .name: "称呼保存失败，当前输入仍保留。"
            case .sex: "性别保存失败，请重试。"
            }
        }
    }

    // 删号流程态
    @State private var deletionImpact: DeletionImpactDTO?
    @State private var loadingImpact = false
    @State private var deleting = false
    @State private var deleteError: String?

    // Sheet / HealthKit / 通知态
    @State private var profileSheet: ProfileSheet?
    @State private var healthAuthorized = false
    @State private var notificationsEnabled: Bool?
    private let calorieDefaults: UserDefaults
    @State private var caloriePreferences: WorkoutCaloriePreferences
    @State private var showBadgeWall = ProcessInfo.processInfo.arguments.contains("-open-badge-wall")

    init(calorieDefaults: UserDefaults = .standard) {
        self.calorieDefaults = calorieDefaults
        _caloriePreferences = State(initialValue: WorkoutCaloriePreferences.current(defaults: calorieDefaults))
    }

    private var badgeGrants: [BadgeGrantCandidate] {
        badgeWallStore.progress.compactMap(\.grant).sorted { $0.unlockedAt > $1.unlockedAt }
    }

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
                        badgeOverviewCard
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let profileSaveFailure {
                LocalSaveRetryBanner(message: profileSaveFailure.message, onRetry: retryProfileSave)
            }
        }
        // 我的页不展示顶部标题，隐藏系统导航栏。
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showBadgeWall) {
            BadgeWallView()
        }
        .onOpenURL { url in
            if url.scheme == "dontlift" && url.host == "badge-wall" {
                showBadgeWall = true
            }
        }
        .onAppear {
            #if DEBUG
            if UITestHooks.testBadgeDetailId != nil {
                showBadgeWall = true
            }
            #endif
        }
        .task {
            WorkoutPerformanceMonitor.event("profile.appear")
            healthAuthorized = healthKit.isAuthorized
            caloriePreferences = .current(defaults: calorieDefaults)
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
        .alert("演示数据", isPresented: Binding(
            get: { seedResult != nil },
            set: { if !$0 { seedResult = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(seedResult ?? "")
        }
        #endif
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
                                .tint(Theme.Color.action)
                        }
                    }
            }
        }
        #endif
    }

    // MARK: - Header

    private var header: some View {
        let name = profile?.displayName ?? "已登录"
        let layout = dynamicTypeSize >= .xxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.md))
            : AnyLayout(HStackLayout(spacing: Theme.Spacing.md))
        return layout {
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
            if dynamicTypeSize < .xxLarge { Spacer() }
        }
    }

    private func avatarCircle(initial: String) -> some View {
        // 头像统一用主色调（朱砂红），与全局单点强调一致。
        ZStack {
            Circle().fill(Theme.Color.accent).frame(width: avatarDiameter, height: avatarDiameter)
            Text(initial)
                .font(Theme.Font.display(size: 28, weight: .bold))
                .foregroundStyle(Theme.Color.bg)
        }
    }

    /// 副标：只展示总训练次数。
    private var headerSubtitle: String {
        "总训练次数 \(totalWorkouts) 次"
    }

    // MARK: - 成就徽章概览卡片

    private var badgeOverviewCard: some View {
        let layout = dynamicTypeSize >= .xxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))
        return Button {
            showBadgeWall = true
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                layout {
                    HStack(spacing: 8) {
                        Image(systemName: "medal.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.Color.action)
                        Text("成就徽章")
                            .font(Theme.Font.body(size: 15, weight: .bold))
                            .foregroundStyle(Theme.Color.fg)
                    }
                    if dynamicTypeSize < .xxLarge { Spacer() }
                    HStack(spacing: 4) {
                        Text("已解锁 \(badgeGrants.count) / \(BadgeDefinition.all.count)")
                            .font(Theme.Font.mono(size: 13, weight: .medium))
                            .foregroundStyle(Theme.Color.fg2)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.Color.muted)
                    }
                }

                if badgeGrants.isEmpty {
                    layout {
                        HStack(spacing: 10) {
                            ForEach(0..<5, id: \.self) { _ in
                                Circle()
                                    .fill(Theme.Color.surface2.opacity(0.6))
                                    .frame(width: 34, height: 34)
                                    .overlay(Circle().stroke(Theme.Color.border, lineWidth: 1))
                            }
                        }
                        Text("完成训练点亮专属勋章")
                            .font(Theme.Font.body(size: 12))
                            .foregroundStyle(Theme.Color.muted)
                            .padding(.leading, 4)
                        if dynamicTypeSize < .xxLarge { Spacer() }
                    }
                    .padding(.top, 2)
                } else {
                    HStack(spacing: 10) {
                        ForEach(badgeGrants.prefix(5), id: \.badgeCode) { grant in
                            if let def = BadgeDefinition.lookup(grant.badgeCode) {
                                BadgeIconView(definition: def, isUnlocked: true, size: .mini)
                            }
                        }
                        if badgeGrants.count < 5 {
                            ForEach(0..<(5 - badgeGrants.count), id: \.self) { _ in
                                Circle()
                                    .fill(Theme.Color.surface2.opacity(0.6))
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Circle()
                                            .stroke(Theme.Color.border, lineWidth: 1)
                                    )
                            }
                        }
                        Spacer()
                    }
                    .padding(.top, 2)
                }
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profile.badge.entry")
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
        Button(action: beginEditName) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "person")
                    .foregroundStyle(Theme.Color.fg2)
                    .font(.system(size: 16))
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
            .padding(.vertical, 8)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("编辑称呼")
        .accessibilityValue(profile?.displayName ?? "未设置")
        .workoutOverlayObstacle()
    }

    private var nameEditingRow: some View {
        let draft = nameDraft.trimmingCharacters(in: .whitespaces)
        let valid = !draft.isEmpty && draft.count <= 20
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "person")
                    .foregroundStyle(Theme.Color.action)
                    .font(.system(size: 16))
                    .frame(width: 24)
                TextField("称呼", text: $nameDraft, prompt: Text("称呼").foregroundColor(Theme.Color.muted))
                    .accessibilityIdentifier("profile.name.input")
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
                    .frame(minWidth: 44, minHeight: 44)
                Button("保存") { saveName() }
                    .accessibilityIdentifier("profile.name.save")
                    .font(Theme.Font.body(size: 13, weight: .semibold))
                    .foregroundStyle(valid ? Theme.Color.action : Theme.Color.muted)
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled(!valid)
            }
            .padding(.leading, 24 + Theme.Spacing.md)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 10)
    }

    private var sexRow: some View {
        let current = profile?.sex ?? .male
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: Theme.Spacing.md))
        return layout {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "figure.stand")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.Color.fg2)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text("性别")
                    .font(Theme.Font.body(size: 14))
                    .foregroundStyle(Theme.Color.fg)
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer() }
            HStack(spacing: 6) {
                ForEach(BodySex.allCases) { s in
                    sexPill(s, selected: current == s)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 8)
        .frame(minHeight: 48)
    }

    private func sexPill(_ s: BodySex, selected: Bool) -> some View {
        Button { setSex(s) } label: {
            Text(s.displayName)
            .font(Theme.Font.body(size: 13, weight: selected ? .semibold : .regular))
            .foregroundStyle(selected ? Color.white : Theme.Color.fg2)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .frame(minWidth: 40, minHeight: 28)
            .background(selected ? Theme.Color.action : Theme.Color.surface2,
                        in: Capsule())
            .overlay(Capsule().stroke(selected ? Color.clear : Theme.Color.border, lineWidth: 1))
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("性别：\(s.displayName)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func beginEditName() {
        nameDraft = profile?.displayName ?? ""
        editingName = true
        nameFieldFocused = true
    }

    private func cancelEditName() {
        if profileSaveFailure == .name { profileSaveFailure = nil }
        editingName = false
        nameFieldFocused = false
    }

    /// 本地保存成功才收起编辑；网络补传失败由会话保留待传标记。
    private func saveName() {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count <= 20 else { return }
        do {
            try session.saveDisplayName(trimmed)
            profileSaveFailure = nil
            Theme.Haptics.selection()
            editingName = false
            nameFieldFocused = false
        } catch { profileSaveFailure = .name }
    }

    /// 切换性别：资料字段，乐观本地写 + PATCH 上行（驱动肌群图 + 回灌后端）。
    private func setSex(_ s: BodySex) {
        // 用 ensureProfile 兜底：desync 场景下（token 在、本地档案缺失）@Query 查不到 profile，
        // 此处补建后再写，避免点击性别胶囊静默无效。
        guard let profile = session.ensureProfile(), profile.sex != s else { return }
        do {
            try session.saveSex(s)
            profileSaveFailure = nil
            Theme.Haptics.selection()
        } catch { profileSaveFailure = .sex(s) }
    }

    private func retryProfileSave() {
        switch profileSaveFailure {
        case .name: saveName()
        case .sex(let sex): setSex(sex)
        case nil: break
        }
    }

    // MARK: - 数据 · 同步

    private var syncGroup: some View {
        groupCard(title: "数据 · 同步") {
            healthKitRow
            rowDivider
            SyncRow(syncEngine: syncEngine)
        }
        .workoutOverlayObstacle()
    }

    /// HealthKit 行：未授权时可点击发起授权，授权态实时刷新。
    private var healthKitRow: some View {
        let available = HKHealthStore.isHealthDataAvailable()
        let status = healthAuthorized ? "已连接" : (available ? "未授权" : "不可用")
        return Button {
            Task {
                await healthKit.requestAuthorization()
                healthAuthorized = healthKit.isAuthorized
            }
        } label: {
            preferenceSummary(title: "HealthKit", icon: "heart.text.square", value: status,
                              valueColor: healthAuthorized ? Theme.Color.ok : Theme.Color.danger)
        }
        .buttonStyle(.plain)
        .disabled(!available || healthAuthorized)
        .accessibilityLabel("HealthKit")
        .accessibilityValue(status)
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
            Toggle(isOn: restTimerHapticsBinding) {
                Label("震动", systemImage: "iphone.radiowaves.left.and.right")
                    .font(Theme.Font.body(size: 14))
                    .foregroundStyle(Theme.Color.fg)
    .frame(minHeight: 44)
            }
            .tint(Theme.Color.action)
            .accessibilityLabel("震动")
            .accessibilityIdentifier("profile.haptics")
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 2)
            .frame(minHeight: 48)

            rowDivider

            // 声音开关：统一控制前台 App 内音效与后台/锁屏本地通知音。
            Toggle(isOn: restTimerSoundBinding) {
                Label("声音", systemImage: "speaker.wave.2")
                    .font(Theme.Font.body(size: 14))
                    .foregroundStyle(Theme.Color.fg)
    .frame(minHeight: 44)
            }
            .tint(Theme.Color.action)
            .accessibilityLabel("声音")
            .accessibilityIdentifier("profile.sound")
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 2)
            .frame(minHeight: 48)

            rowDivider

            // 通知（展示系统授权态 + 跳系统设置）
            Button(action: openSystemSettings) {
                preferenceSummary(title: "通知", icon: "bell", value: notificationStatusText,
                                  valueColor: notificationsEnabled == true ? Theme.Color.ok : Theme.Color.muted,
                                  disclosure: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("通知设置")
            .accessibilityValue(notificationStatusText)
        }
    }

    private var defaultRestDurationRow: some View {
        Button { profileSheet = .restDuration } label: {
            preferenceSummary(title: "默认休息时长", icon: "timer",
                              value: profileRestDurationText(restTimer.defaultDuration), disclosure: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("默认休息时长")
        .accessibilityValue(profileRestDurationText(restTimer.defaultDuration))
        .accessibilityIdentifier("profile.defaultRest")
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
        Toggle(isOn: calorieEstimateEnabledBinding) {
            Label("消耗估算", systemImage: "flame")
                .font(Theme.Font.body(size: 14))
                .foregroundStyle(Theme.Color.fg)
    .frame(minHeight: 44)
        }
        .tint(Theme.Color.action)
        .accessibilityLabel("消耗估算")
        .accessibilityIdentifier("profile.calorieEstimate")
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 2)
        .frame(minHeight: 48)
    }

    private var calorieBodyWeightRow: some View {
        Button {
            profileSheet = .calorieWeight(enableAfterSave: calorieEstimatesEnabled)
        } label: {
            preferenceSummary(title: "估算体重", icon: "scalemass", value: calorieBodyWeightText,
                              valueColor: calorieBodyWeightColor, disclosure: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("估算体重")
        .accessibilityValue(calorieBodyWeightText)
    }

    private var calorieBodyWeightText: String {
        guard let kg = caloriePreferences.bodyWeightKg else {
            return "未设置（可选）"
        }
        return "\(formatKg(kg))kg"
    }

    private var calorieBodyWeightColor: Color {
        caloriePreferences.bodyWeightKg == nil
            ? Theme.Color.muted
            : Theme.Color.fg
    }

    private func setCalorieEstimatesEnabled(_ enabled: Bool) {
        if enabled, caloriePreferences.bodyWeightKg == nil {
            profileSheet = .calorieWeight(enableAfterSave: true)
            return
        }
        WorkoutCaloriePreferences.setShowsEstimates(enabled, defaults: calorieDefaults)
        caloriePreferences = WorkoutCaloriePreferences.current(defaults: calorieDefaults)
    }

    private func saveCalorieBodyWeight(_ kg: Double, enableAfterSave: Bool) {
        WorkoutCaloriePreferences.setBodyWeightKg(kg, defaults: calorieDefaults)
        WorkoutCaloriePreferences.setShowsEstimates(enableAfterSave, defaults: calorieDefaults)
        caloriePreferences = WorkoutCaloriePreferences.current(defaults: calorieDefaults)
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
                Image(systemName: "info.circle").foregroundStyle(Theme.Color.fg2).font(.system(size: 16)).frame(width: 24)
                Text("版本")
                    .font(Theme.Font.body(size: 14))
                    .foregroundStyle(Theme.Color.fg)
                Spacer()
                Text(appVersion)
                    .font(Theme.Font.mono(size: 12))
                    .foregroundStyle(Theme.Color.muted)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 8)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
            .onTapGesture { handleVersionTap() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("版本")
            .accessibilityValue(appVersion)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { handleVersionTap() }

            rowDivider
            legalRow(icon: "hand.raised", title: "隐私政策", url: AppConfig.privacyPolicyURL)
            rowDivider
            legalRow(icon: "doc.text", title: "服务条款", url: AppConfig.termsOfServiceURL)
            #if DEBUG
            rowDivider
            // DEBUG-only：为 Simulator 测试账号一键生成近 6 周演示训练与计划。
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "hammer").foregroundStyle(Theme.Color.fg2).font(.system(size: 16)).frame(width: 24)
                Text("生成演示数据")
                    .font(Theme.Font.body(size: 14))
                    .foregroundStyle(Theme.Color.fg)
                Spacer()
                Text("开发")
                    .font(Theme.Font.mono(size: 11))
                    .foregroundStyle(Theme.Color.muted)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 8)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
            .onTapGesture { seedDemoData() }
            .accessibilityLabel("生成演示数据")
            .accessibilityHint("生成近 6 周演示训练与计划（仅开发环境）")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { seedDemoData() }
            #endif
        }
    }

    #if DEBUG
    /// 生成演示数据并立即触发历史投影重建，首页与复盘页即刻可见。
    private func seedDemoData() {
        do {
            if caloriePreferences.bodyWeightKg == nil {
                WorkoutCaloriePreferences.setBodyWeightKg(75.0, defaults: calorieDefaults)
                caloriePreferences = WorkoutCaloriePreferences.current(defaults: calorieDefaults)
            }
            let result = try WorkoutDemoSeedData.seed(in: modelContext)
            historyStore.scheduleRefresh(reason: .workoutChanged, delayNanoseconds: 0)

            UserDefaults.standard.removeObject(forKey: BadgeEngine.backfillCompletedKey)
            UserDefaults.standard.removeObject(forKey: BadgeEngine.careerReviewShownKey)
            Task { @MainActor in
                let backfilledGrants = await BadgeEngine.runBackfillIfNeeded(in: modelContext, force: true)
                seedResult = "已生成 \(result.workouts) 次训练、\(result.plans) 个计划，并解锁/回溯了 \(backfilledGrants.count) 枚成就勋章。"
            }
        } catch {
            seedResult = "生成失败：\(error.localizedDescription)"
        }
    }
    #endif

    private func legalRow(icon: String, title: String, url: URL) -> some View {
        Button { profileSheet = .legal(url) } label: {
            preferenceSummary(title: title, icon: icon, disclosure: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    /// 标签与值在大字下纵排，触达区位于真实 Button label 内。
    private func preferenceSummary(title: String, icon: String, value: String? = nil,
                                   valueColor: Color = Theme.Color.fg, disclosure: Bool = false) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Theme.Color.fg2)
                .frame(width: 24)
                .accessibilityHidden(true)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                : AnyLayout(HStackLayout(spacing: Theme.Spacing.md))
            layout {
                Text(title)
                    .font(Theme.Font.body(size: 14))
                    .foregroundStyle(Theme.Color.fg)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                if let value {
                    Text(value)
                        .font(Theme.Font.mono(size: 12))
                        .foregroundStyle(valueColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if disclosure {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Color.muted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 8)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
        .workoutOverlayObstacle()
    }

    // MARK: - 账号

    private var accountGroup: some View {
        groupCard(title: "账号") {
            // 退出登录
            Button { confirmLogout = true } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(Theme.Color.danger).font(.system(size: 16)).frame(width: 24)
                    Text("退出登录")
                        .font(Theme.Font.body(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Color.danger)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 8)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(deleting)
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
                session.beginDeletedAccountCleanup()
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

struct CalorieBodyWeightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("体重")
                        .eyebrowStyle()

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        TextField("30–250", text: $weightText, prompt: Text("30–250").foregroundColor(Theme.Color.muted))
                            .accessibilityIdentifier("profile.calorieWeight.input")
                            .font(Theme.Font.number(size: 30, weight: .bold))
                            .foregroundStyle(Theme.Color.fg)
                            .keyboardType(.decimalPad)
                            .focused($weightFocused)
                        Text("kg")
                            .font(Theme.Font.body(size: 14, weight: .bold))
                            .foregroundStyle(Theme.Color.muted)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, 10)
                    .frame(minHeight: 68)
                    .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .stroke(inputBorderColor, lineWidth: 1)
                    )

                    Text(helperText)
                        .accessibilityIdentifier("profile.calorieWeight.helper")
                        .font(Theme.Font.mono(size: 11))
                        .foregroundStyle(helperColor)
                }
                .padding(Theme.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.Color.bg.ignoresSafeArea())
        .presentationBackground(Theme.Color.bg)
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(260)])
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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

            ScrollView {
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
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.Color.bg.ignoresSafeArea())
        .presentationBackground(Theme.Color.bg)
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(260)])
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
        VStack(spacing: 6) {
            TextField("0", text: text, prompt: Text("0").foregroundColor(Theme.Color.muted))
                .font(Theme.Font.number(size: 28, weight: .bold))
                .foregroundStyle(Theme.Color.fg)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .focused($focusedField, equals: field)
                .padding(.horizontal, Theme.Spacing.md)
                .accessibilityLabel(title)
            Text(title)
                .font(Theme.Font.body(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Color.muted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .frame(minHeight: 68)
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
        Button {
            Task { await syncEngine.syncAll() }
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(Theme.Color.fg2)
                        .font(.system(size: 16))
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    Text("立即同步")
                        .font(Theme.Font.body(size: 14))
                        .foregroundStyle(Theme.Color.fg)
                    Spacer()
                    if syncEngine.isSyncing {
                        ProgressView().tint(Theme.Color.action)
                            .accessibilityHidden(true)
                    }
                    Text(syncEngine.isSyncing ? "同步中…" : (syncEngine.lastResult?.summary ?? "尚未同步"))
                        .font(Theme.Font.l5)
                        .foregroundStyle(Theme.Color.fg2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !syncEngine.isSyncing, let hint = syncEngine.lastResult?.recoveryHint {
                    Text(hint)
                        .font(Theme.Font.l5)
                        .foregroundStyle(Theme.Color.fg2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 24 + Theme.Spacing.md)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(syncEngine.isSyncing)
        .accessibilityIdentifier("profile.sync")
        .accessibilityLabel("立即同步")
        .accessibilityValue(syncEngine.isSyncing ? "同步中" : (syncEngine.lastResult?.summary ?? "尚未同步"))
        .accessibilityHint(syncEngine.isSyncing ? "正在同步，请稍候。"
                           : (syncEngine.lastResult?.recoveryHint ?? "同步本机与账号中的训练数据"))
    }
}
