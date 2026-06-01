import SwiftUI
import SwiftData

// MARK: - Team 列表（tab 根）

struct TeamListView: View {
    @Environment(TeamService.self) private var teamService
    @State private var creating = false
    @State private var joining = false
    @State private var error: String?

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if teamService.teams.isEmpty {
                        emptyCard
                    } else {
                        Text("我的 Team").eyebrowStyle()
                        ForEach(teamService.teams) { team in
                            NavigationLink(value: team) {
                                teamCard(team)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Color.clear.frame(height: 32)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }
        }
        .navigationTitle("Team")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("创建 Team") { creating = true }
                    Button("用邀请码加入") { joining = true }
                } label: {
                    Image(systemName: "plus").foregroundStyle(Theme.Color.fg)
                }
            }
        }
        .navigationDestination(for: TeamDTO.self) { TeamDetailView(team: $0) }
        .sheet(isPresented: $creating) { CreateTeamSheet() }
        .sheet(isPresented: $joining) { JoinTeamSheet() }
        .task { await reload() }
        .refreshable { await reload() }
        .alert("出错了", isPresented: .constant(error != nil)) {
            Button("好") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func teamCard(_ team: TeamDTO) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.Color.surface2)
                    .frame(width: 56, height: 56)
                Text(String(team.name.prefix(1)))
                    .font(Theme.Font.display(size: 22, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(team.name)
                    .font(Theme.Font.body(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                Text("邀请码 \(team.inviteCode)")
                    .font(Theme.Font.mono(size: 11))
                    .foregroundStyle(Theme.Color.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("EMPTY · Team").eyebrowStyle()
            Text("还没有 Team")
                .font(Theme.Font.display(size: 20, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
            Text("创建一个小队，或用邀请码加入训练搭子的圈子。")
                .font(Theme.Font.body(size: 13))
                .foregroundStyle(Theme.Color.fg2)
            HStack(spacing: Theme.Spacing.md) {
                Button { creating = true } label: {
                    Text("创建 Team")
                        .font(Theme.Font.body(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Color.bg)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .frame(height: 40)
                        .background(Theme.Color.accentCyan, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .buttonStyle(.plain)
                .neonGlow(.cyan, intensity: .sm, cornerRadius: Theme.Radius.md)
                Button { joining = true } label: {
                    Text("加入")
                        .font(Theme.Font.body(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Color.fg)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .frame(height: 40)
                        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.Color.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func reload() async {
        do { try await teamService.loadMyTeams() }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
    }
}

// MARK: - 创建 / 加入 sheet

struct CreateTeamSheet: View {
    @Environment(TeamService.self) private var teamService
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            // 必要的 Form 用法：单字段录入 sheet，原生体验最稳。
            Form {
                Section("名称") { TextField("如：周三力量小队", text: $name) }
                if let error { Text(error).foregroundStyle(Theme.Color.danger).font(.caption) }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Color.bg)
            .navigationTitle("创建 Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") { Task { await submit() } }
                        .disabled(busy || name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .tint(Theme.Color.accentCyan)
                }
            }
        }
    }

    private func submit() async {
        busy = true; defer { busy = false }
        do { _ = try await teamService.create(name: name.trimmingCharacters(in: .whitespaces)); dismiss() }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
    }
}

struct JoinTeamSheet: View {
    @Environment(TeamService.self) private var teamService
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("邀请码") {
                    TextField("输入队友给你的邀请码", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                if let error { Text(error).foregroundStyle(Theme.Color.danger).font(.caption) }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Color.bg)
            .navigationTitle("加入 Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("加入") { Task { await submit() } }
                        .disabled(busy || code.trimmingCharacters(in: .whitespaces).isEmpty)
                        .tint(Theme.Color.accentCyan)
                }
            }
        }
    }

    private func submit() async {
        busy = true; defer { busy = false }
        do { _ = try await teamService.join(inviteCode: code.trimmingCharacters(in: .whitespaces)); dismiss() }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
    }
}

// MARK: - Team 详情（Screen 09，Neon 改版）

struct TeamDetailView: View {
    @Environment(TeamService.self) private var teamService
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    let team: TeamDTO
    @State private var members: [TeamMemberDTO] = []
    @State private var checkins: [TeamCheckinDTO] = []
    @State private var reactions: [UUID: [CheckinReactionDTO]] = [:]
    @State private var error: String?
    @State private var confirmLeave = false

    private var isOwner: Bool { team.ownerUserId == session.currentUserId }

    /// 3 档颜色 hash 头像配色。
    private static let avatarPalette: [Color] = [
        Theme.Color.accentCyan,
        Theme.Color.accentMagenta,
        Theme.Color.ok,
    ]

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    coverCard
                    membersStrip

                    Text("今日动态").eyebrowStyle()
                    if checkins.isEmpty {
                        emptyFeedCard
                    } else {
                        VStack(spacing: Theme.Spacing.md) {
                            ForEach(checkins) { c in
                                FeedItemCard(
                                    checkin: c,
                                    mine: c.userId == session.currentUserId,
                                    memberName: memberName(userId: c.userId),
                                    avatarColor: avatarColor(for: c.userId),
                                    reactions: reactions[c.id] ?? [],
                                    myUserId: session.currentUserId,
                                    onReact: { emoji in await react(checkinId: c.id, emoji: emoji) }
                                )
                            }
                        }
                    }

                    NavigationLink {
                        TeamPlansView(team: team)
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet.rectangle").foregroundStyle(Theme.Color.accentCyan)
                            Text("Team 计划模板")
                                .font(Theme.Font.body(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.Color.fg)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Theme.Color.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                    }
                    .buttonStyle(.plain)

                    Button(isOwner ? "解散 Team" : "退出 Team") {
                        confirmLeave = true
                    }
                    .font(Theme.Font.body(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Color.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)

                    Color.clear.frame(height: 32)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }
        }
        .navigationTitle(team.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .refreshable { await reload() }
        .confirmationDialog(isOwner ? "解散后该 Team 不可恢复" : "确定退出该 Team？",
                            isPresented: $confirmLeave, titleVisibility: .visible) {
            Button(isOwner ? "解散" : "退出", role: .destructive) { Task { await leaveOrDissolve() } }
        }
        .alert("出错了", isPresented: .constant(error != nil)) {
            Button("好") { error = nil }
        } message: { Text(error ?? "") }
    }

    // 顶部 cover 卡：gradient surface2→bg + 圆角 lg + 右上「N/M 今日已练」pill。
    private var coverCard: some View {
        let totalMembers = members.count
        let trainedToday = Set(checkins.map(\.userId)).count
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("TEAM").eyebrowStyle()
                Spacer()
                Text("\(trainedToday) / \(totalMembers) 今日已练")
                    .font(Theme.Font.mono(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Theme.Color.bg.opacity(0.55), in: Capsule())
                    .overlay(Capsule().stroke(Theme.Color.border, lineWidth: 1))
            }
            Text(team.name)
                .font(Theme.Font.display(size: 24, weight: .bold))
                .foregroundStyle(Theme.Color.fg)
            HStack(spacing: 6) {
                Text("邀请码")
                    .font(Theme.Font.mono(size: 11))
                    .foregroundStyle(Theme.Color.muted)
                Text(team.inviteCode)
                    .font(Theme.Font.mono(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                Button {
                    UIPasteboard.general.string = team.inviteCode
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Color.fg2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Theme.Color.surface2, Theme.Color.bg],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Theme.Radius.lg)
        )
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.Color.border, lineWidth: 1))
    }

    // 成员头像横向条：4 档配色 hash，超 4 折叠 +N，尾部 mono「N 成员」。
    private var membersStrip: some View {
        let shown = Array(members.prefix(4))
        let overflow = max(0, members.count - shown.count)
        return HStack(spacing: -8) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { _, m in
                avatarCircle(name: memberName(m), color: avatarColor(for: m.userId))
            }
            if overflow > 0 {
                ZStack {
                    Circle()
                        .fill(Theme.Color.surface)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(Theme.Color.bg, lineWidth: 2))
                    Text("+\(overflow)")
                        .font(Theme.Font.mono(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Color.fg2)
                }
            }
            Spacer()
            Text("\(members.count) 成员")
                .font(Theme.Font.mono(size: 11))
                .foregroundStyle(Theme.Color.muted)
        }
    }

    private func avatarCircle(name: String, color: Color) -> some View {
        ZStack {
            Circle().fill(color).frame(width: 36, height: 36)
            Circle().stroke(Theme.Color.bg, lineWidth: 2).frame(width: 36, height: 36)
            Text(String(name.prefix(1)))
                .font(Theme.Font.body(size: 13, weight: .bold))
                .foregroundStyle(Theme.Color.bg)
        }
    }

    private var emptyFeedCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("今天还没人打卡")
                .font(Theme.Font.body(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
            Text("第一个完成训练的人，自动出现在这里。")
                .font(Theme.Font.body(size: 13))
                .foregroundStyle(Theme.Color.fg2)
            NavigationLink {
                WorkoutListView()
            } label: {
                Text("开始训练")
                    .font(Theme.Font.body(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Color.bg)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .frame(height: 38)
                    .background(Theme.Color.accentCyan, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
            .buttonStyle(.plain)
            .neonGlow(.cyan, intensity: .sm, cornerRadius: Theme.Radius.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func avatarColor(for userId: UUID) -> Color {
        let h = abs(userId.hashValue)
        return Self.avatarPalette[h % Self.avatarPalette.count]
    }

    private func memberName(_ m: TeamMemberDTO) -> String { memberName(userId: m.userId) }

    private func memberName(userId: UUID) -> String {
        if userId == session.currentUserId { return "我" }
        return "队友 " + userId.uuidString.prefix(4)
    }

    private func reload() async {
        do {
            async let m = teamService.members(of: team.id)
            async let c = teamService.checkins(teamId: team.id)
            members = try await m
            checkins = try await c
            await loadReactions()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func loadReactions() async {
        var map: [UUID: [CheckinReactionDTO]] = [:]
        for c in checkins {
            map[c.id] = (try? await teamService.reactions(checkinId: c.id)) ?? []
        }
        reactions = map
    }

    /// 6.5 乐观更新：先本地追加/移除，再请求；失败则回滚 + 弹错。
    private func react(checkinId: UUID, emoji: String) async {
        guard let myId = session.currentUserId else { return }
        let prior = reactions[checkinId] ?? []
        var next = prior
        if let i = next.firstIndex(where: { $0.userId == myId && $0.emoji == emoji }) {
            // 已点亮 → 取消（本地预测；服务端 toggle 由 react() 处理）
            next.remove(at: i)
        } else {
            next.append(CheckinReactionDTO(id: UUID(), checkinId: checkinId, userId: myId, emoji: emoji))
        }
        reactions[checkinId] = next
        do {
            _ = try await teamService.react(checkinId: checkinId, emoji: emoji)
            let server = (try? await teamService.reactions(checkinId: checkinId)) ?? next
            reactions[checkinId] = server
        } catch {
            reactions[checkinId] = prior
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func leaveOrDissolve() async {
        do {
            if isOwner { try await teamService.dissolve(team.id) }
            else { try await teamService.leave(team.id) }
            dismiss()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - FeedItemCard

struct FeedItemCard: View {
    let checkin: TeamCheckinDTO
    let mine: Bool
    let memberName: String
    let avatarColor: Color
    let reactions: [CheckinReactionDTO]
    let myUserId: UUID?
    let onReact: (String) async -> Void

    @State private var busy = false

    /// 设计稿 4 emoji：🔥/💪/😱/👏。当前后端 enum 仅有 fire/muscle/clap/heart，
    /// 用 heart 替代 😱（震惊）以保持顺序稳定；后续扩 enum 再换。
    private let displayEmojis: [(code: String, glyph: String)] = [
        ("fire", "🔥"),
        ("muscle", "💪"),
        ("heart", "❤️"),
        ("clap", "👏"),
    ]

    private var summary: CheckinSummary { checkin.parsedSummary }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            head
            body(text: bodyText)
            ReactionRow(
                reactions: reactions,
                myUserId: myUserId,
                emojis: displayEmojis,
                onTap: { emoji in
                    guard !busy else { return }
                    Task { busy = true; await onReact(emoji); busy = false }
                }
            )
            .disabled(busy)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var head: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle().fill(avatarColor).frame(width: 32, height: 32)
                Text(String(memberName.prefix(1)))
                    .font(Theme.Font.body(size: 12, weight: .bold))
                    .foregroundStyle(Theme.Color.bg)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(memberName + (mine ? " · 你" : ""))
                    .font(Theme.Font.body(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                Text(relativeTime(checkin.createdAt ?? Date()))
                    .font(Theme.Font.mono(size: 10))
                    .foregroundStyle(Theme.Color.muted)
            }
            Spacer()
        }
    }

    private var bodyText: AttributedString {
        var s = AttributedString("完成训练 · ")
        s.foregroundColor = Theme.Color.fg2

        var name = AttributedString(summary.title ?? "训练")
        name.foregroundColor = Theme.Color.fg
        s.append(name)

        if summary.totalVolumeKg > 0 {
            var sep = AttributedString(" · ")
            sep.foregroundColor = Theme.Color.fg2
            s.append(sep)
            var vol = AttributedString("\(formatKg(summary.totalVolumeKg)) kg")
            vol.foregroundColor = Theme.Color.fg
            s.append(vol)
        }
        if let pr = summary.headlinePR {
            var sep = AttributedString("  ")
            sep.foregroundColor = Theme.Color.fg2
            s.append(sep)
            var prAttr = AttributedString("★ \(pr)")
            prAttr.foregroundColor = Theme.Color.accentMagenta
            s.append(prAttr)
        }
        return s
    }

    @ViewBuilder
    private func body(text: AttributedString) -> some View {
        if summary.headlinePR != nil {
            Text(text)
                .font(Theme.Font.body(size: 14, weight: .semibold))
                .neonGlow(.magenta, intensity: .sm, cornerRadius: Theme.Radius.sm)
        } else {
            Text(text)
                .font(Theme.Font.body(size: 14, weight: .semibold))
        }
    }

    private func relativeTime(_ d: Date) -> String {
        d.formatted(.relative(presentation: .named))
    }
}

private extension CheckinSummary {
    /// 从汇总里提炼一段「PR …」高亮文字；MVP 仅根据 `headline` 文字匹配。
    var headlinePR: String? {
        let text = headline
        if let range = text.range(of: "PR") {
            return String(text[range.lowerBound...]).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
}

// MARK: - 反应行

struct ReactionRow: View {
    let reactions: [CheckinReactionDTO]
    let myUserId: UUID?
    let emojis: [(code: String, glyph: String)]
    let onTap: (String) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(emojis, id: \.code) { item in
                let count = reactions.filter { $0.emoji == item.code }.count
                let mine = myUserId.map { my in
                    reactions.contains(where: { $0.userId == my && $0.emoji == item.code })
                } ?? false
                Button { onTap(item.code) } label: {
                    HStack(spacing: 4) {
                        Text(item.glyph)
                            .font(.system(size: 14))
                        if count > 0 {
                            Text("\(count)")
                                .font(Theme.Font.mono(size: 11, weight: .semibold))
                                .foregroundStyle(mine ? Theme.Color.fg : Theme.Color.fg2)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(
                        mine ? Theme.Color.surface2 : Theme.Color.surface,
                        in: Capsule()
                    )
                    .overlay(Capsule().stroke(mine ? Theme.Color.accentCyan.opacity(0.4) : Theme.Color.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Button { /* + 自定义反应：本 change 不实现 */ } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Color.muted)
                    .frame(width: 28, height: 28)
                    .background(Theme.Color.surface, in: Circle())
                    .overlay(Circle().stroke(Theme.Color.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(true)
            Spacer()
        }
    }
}

// MARK: - 打卡详情（保留供 deep link 用，本 change 不重做样式）

struct CheckinDetailView: View {
    @Environment(TeamService.self) private var teamService
    @Environment(SessionStore.self) private var session

    let checkin: TeamCheckinDTO
    let isMine: Bool
    @State private var reactions: [CheckinReactionDTO] = []
    @State private var error: String?
    @State private var sharingSummary: CheckinSummary?

    private var summary: CheckinSummary { checkin.parsedSummary }

    var body: some View {
        // 必要的 List 用法：详情页结构稳定、且不在 Team feed 主视觉范围。
        List {
            Section {
                LabeledContent("动作", value: "\(summary.exerciseCount)")
                LabeledContent("总组数", value: "\(summary.totalSets)")
                if summary.totalVolumeKg > 0 {
                    LabeledContent("总容量", value: "\(formatKg(summary.totalVolumeKg)) kg")
                }
            } header: { Text(summary.title ?? "训练") }

            ForEach(summary.exercises) { ex in
                Section(ex.name) {
                    ForEach(Array(ex.sets.enumerated()), id: \.offset) { idx, set in
                        HStack {
                            Text("第 \(idx + 1) 组").foregroundStyle(Theme.Color.muted)
                            Spacer()
                            Text(setText(set))
                        }
                        .font(.callout)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Color.bg)
        .navigationTitle(isMine ? "我的训练" : "队友训练")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { sharingSummary = summary } label: { Image(systemName: "square.and.arrow.up") }
            }
        }
        .sheet(item: $sharingSummary) { SharePosterSheet(summary: $0) }
        .task { reactions = (try? await teamService.reactions(checkinId: checkin.id)) ?? [] }
        .alert("出错了", isPresented: .constant(error != nil)) {
            Button("好") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func setText(_ s: CheckinSummary.SetSummary) -> String {
        let w = s.weightKg.map { "\(formatKg($0)) kg" } ?? "—"
        let r = s.reps.map { "\($0) 次" } ?? "—"
        return "\(w) × \(r)"
    }
}

// MARK: - Team 计划浏览（保留功能，theme 微调）

struct TeamPlansView: View {
    @Environment(TeamService.self) private var teamService
    @Environment(SyncEngine.self) private var syncEngine

    let team: TeamDTO
    @State private var plans: [ServerPlanDTO] = []
    @State private var error: String?
    @State private var toast: String?
    @State private var forking: UUID?

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if plans.isEmpty {
                        Text("还没有成员发布计划")
                            .font(Theme.Font.body(size: 13))
                            .foregroundStyle(Theme.Color.muted)
                            .padding(.top, Theme.Spacing.lg)
                    }
                    ForEach(plans) { p in
                        planRow(p)
                    }
                    Color.clear.frame(height: 32)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }
        }
        .navigationTitle("Team 计划")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .refreshable { await reload() }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(Theme.Font.body(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Color.bg)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Theme.Color.accentCyan, in: Capsule())
                    .padding(.bottom, 24)
                    .transition(.opacity)
            }
        }
        .alert("出错了", isPresented: .constant(error != nil)) {
            Button("好") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func planRow(_ p: ServerPlanDTO) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(p.name)
                    .font(Theme.Font.body(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                Text("\(p.itemCount) 个动作")
                    .font(Theme.Font.mono(size: 11))
                    .foregroundStyle(Theme.Color.muted)
            }
            Spacer()
            Button { Task { await fork(p) } } label: {
                if forking == p.id {
                    ProgressView().tint(Theme.Color.accentCyan)
                } else {
                    Text("Fork")
                        .font(Theme.Font.body(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Color.bg)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(Theme.Color.accentCyan, in: Capsule())
                }
            }
            .buttonStyle(.plain)
            .disabled(forking != nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func reload() async {
        do { plans = try await teamService.plans(of: team.id) }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
    }

    private func fork(_ p: ServerPlanDTO) async {
        forking = p.id; defer { forking = nil }
        do {
            try await teamService.fork(planId: p.id)
            await syncEngine.syncAll()
            await showToast("已 Fork 到「计划」")
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func showToast(_ msg: String) async {
        withAnimation { toast = msg }
        try? await Task.sleep(for: .seconds(2))
        withAnimation { toast = nil }
    }
}
