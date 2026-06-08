import SwiftUI
import SwiftData
import HealthKit

// MARK: - 个人中心（Screen 11，Neon 改版）

struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @Environment(SyncEngine.self) private var syncEngine

    @Query private var profiles: [UserProfile]
    @Query(filter: #Predicate<Workout> { $0.deletedAt == nil && $0.endedAt != nil })
    private var workouts: [Workout]

    @State private var confirmLogout = false
    @State private var versionTapCount = 0
    @State private var showDesignSystem = false

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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    header
                    statsGrid
                    syncGroup
                    aboutGroup
                    logoutButton
                    Color.clear.frame(height: 32)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }
        }
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("确定退出登录？", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) { session.logout() }
        }
        #if DEBUG
        .navigationDestination(isPresented: $showDesignSystem) { DesignSystemPreviewView() }
        #endif
    }

    // MARK: - Header

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

    // MARK: - 设置分组

    private var syncGroup: some View {
        groupCard(title: "数据 · 同步") {
            healthKitRow
            rowDivider
            SyncRow(syncEngine: syncEngine)
        }
    }

    /// HealthKit 连接态：纯展示行（详细授权流程留待后续单独立项，无二级页）。
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
            Text(available ? "已连接" : "未授权")
                .font(Theme.Font.mono(size: 12))
                .foregroundStyle(available ? Theme.Color.ok : Theme.Color.danger)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: 48)
    }

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
        }
    }

    private var logoutButton: some View {
        Button { confirmLogout = true } label: {
            Text("退出登录")
                .font(Theme.Font.body(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Color.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
        }
        .buttonStyle(.plain)
    }

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


