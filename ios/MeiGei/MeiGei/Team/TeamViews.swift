import SwiftUI
import SwiftData

// MARK: - 5.5 Team 列表（Tab 根）

struct TeamListView: View {
    @Environment(TeamService.self) private var teamService
    @State private var creating = false
    @State private var joining = false
    @State private var error: String?

    var body: some View {
        List {
            ForEach(teamService.teams) { team in
                NavigationLink(value: team) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(team.name).foregroundStyle(Theme.Color.fg)
                        Text("邀请码 \(team.inviteCode)").font(.caption).foregroundStyle(Theme.Color.fg2)
                    }
                }
                .listRowBackground(Theme.Color.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Color.bg)
        .navigationTitle("Team")
        .overlay {
            if teamService.teams.isEmpty {
                ContentUnavailableView("还没有 Team", systemImage: "person.3",
                                       description: Text("创建一个，或用邀请码加入训练搭子"))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("创建 Team", systemImage: "plus") { creating = true }
                    Button("用邀请码加入", systemImage: "person.badge.plus") { joining = true }
                } label: { Image(systemName: "plus") }
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

    private func reload() async {
        do { try await teamService.loadMyTeams() }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
    }
}

// MARK: - 创建 / 加入

struct CreateTeamSheet: View {
    @Environment(TeamService.self) private var teamService
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("名称") { TextField("如：周三力量小队", text: $name) }
                if let error { Text(error).foregroundStyle(.red).font(.caption) }
            }
            .navigationTitle("创建 Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") { Task { await submit() } }
                        .disabled(busy || name.trimmingCharacters(in: .whitespaces).isEmpty)
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
                if let error { Text(error).foregroundStyle(.red).font(.caption) }
            }
            .navigationTitle("加入 Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("加入") { Task { await submit() } }
                        .disabled(busy || code.trimmingCharacters(in: .whitespaces).isEmpty)
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

// MARK: - 5.5 Team 详情：邀请码 / 成员 / 当日打卡

struct TeamDetailView: View {
    @Environment(TeamService.self) private var teamService
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    let team: TeamDTO
    @State private var members: [TeamMemberDTO] = []
    @State private var checkins: [TeamCheckinDTO] = []
    @State private var error: String?
    @State private var confirmLeave = false

    private var isOwner: Bool { team.ownerUserId == session.currentUserId }

    var body: some View {
        List {
            Section("邀请码") {
                HStack {
                    Text(team.inviteCode).font(.title3.monospaced())
                    Spacer()
                    Button {
                        UIPasteboard.general.string = team.inviteCode
                    } label: { Label("复制", systemImage: "doc.on.doc") }
                        .labelStyle(.iconOnly)
                }
            }

            Section("成员（\(members.count)/10）") {
                ForEach(members) { m in
                    HStack {
                        Text(memberName(m))
                        if m.role == "owner" {
                            Text("教练").font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.tint.opacity(0.15), in: Capsule())
                        }
                        Spacer()
                    }
                }
            }

            Section("今日打卡") {
                if checkins.isEmpty {
                    Text("今天还没人打卡").foregroundStyle(.secondary).font(.callout)
                }
                ForEach(checkins) { c in
                    NavigationLink {
                        CheckinDetailView(checkin: c, isMine: c.userId == session.currentUserId)
                    } label: {
                        CheckinRowView(checkin: c, mine: c.userId == session.currentUserId,
                                       memberName: memberName(userId: c.userId))
                    }
                }
            }

            Section {
                NavigationLink {
                    TeamPlansView(team: team)
                } label: { Label("Team 计划模板", systemImage: "list.bullet.rectangle") }
            }

            Section {
                if isOwner {
                    Button("解散 Team", role: .destructive) { confirmLeave = true }
                } else {
                    Button("退出 Team", role: .destructive) { confirmLeave = true }
                }
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

    private func reload() async {
        do {
            async let m = teamService.members(of: team.id)
            async let c = teamService.checkins(teamId: team.id)
            members = try await m
            checkins = try await c
        } catch {
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

    private func memberName(_ m: TeamMemberDTO) -> String { memberName(userId: m.userId) }

    private func memberName(userId: UUID) -> String {
        if userId == session.currentUserId { return "我" }
        return "队友 " + userId.uuidString.prefix(4)
    }
}

// MARK: - 打卡行（摘要 + 表情计数只读展示）

struct CheckinRowView: View {
    @Environment(TeamService.self) private var teamService
    let checkin: TeamCheckinDTO
    let mine: Bool
    let memberName: String
    @State private var reactions: [CheckinReactionDTO] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(memberName).font(.subheadline.bold())
                if mine { Text("· 你的训练").font(.caption).foregroundStyle(.secondary) }
                Spacer()
            }
            Text(checkin.parsedSummary.headline).font(.caption).foregroundStyle(.secondary)
            if !reactions.isEmpty {
                Text(reactionDigest).font(.caption2)
            }
        }
        .task {
            reactions = (try? await teamService.reactions(checkinId: checkin.id)) ?? []
        }
    }

    /// 「💪2 🔥1」紧凑计数。
    private var reactionDigest: String {
        let grouped = Dictionary(grouping: reactions, by: \.emoji)
        return ReactionEmoji.allCases.compactMap { e -> String? in
            let n = grouped[e.rawValue]?.count ?? 0
            return n > 0 ? "\(e.glyph)\(n)" : nil
        }.joined(separator: "  ")
    }
}

// MARK: - 5.5 打卡详情（每组重量×次数）+ 5.7 表情回应发送 + 5.8 海报入口

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
                            Text("第 \(idx + 1) 组").foregroundStyle(.secondary)
                            Spacer()
                            Text(setText(set))
                        }
                        .font(.callout)
                    }
                }
            }

            Section("表情回应") {
                ReactionBar(reactions: reactions, myUserId: session.currentUserId) { emoji in
                    await react(emoji)
                }
            }
        }
        .navigationTitle(isMine ? "我的训练" : "队友训练")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { sharingSummary = summary } label: { Image(systemName: "square.and.arrow.up") }
            }
        }
        .sheet(item: $sharingSummary) { SharePosterSheet(summary: $0) }
        .task { await loadReactions() }
        .alert("出错了", isPresented: .constant(error != nil)) {
            Button("好") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func setText(_ s: CheckinSummary.SetSummary) -> String {
        let w = s.weightKg.map { "\(formatKg($0)) kg" } ?? "—"
        let r = s.reps.map { "\($0) 次" } ?? "—"
        return "\(w) × \(r)"
    }

    private func loadReactions() async {
        reactions = (try? await teamService.reactions(checkinId: checkin.id)) ?? []
    }

    private func react(_ emoji: String) async {
        do {
            try await teamService.react(checkinId: checkin.id, emoji: emoji)
            await loadReactions()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - 5.7 四表情回应条

struct ReactionBar: View {
    let reactions: [CheckinReactionDTO]
    let myUserId: UUID?
    let onTap: (String) async -> Void
    @State private var busy = false

    var body: some View {
        HStack(spacing: 16) {
            ForEach(ReactionEmoji.allCases) { e in
                let count = reactions.filter { $0.emoji == e.rawValue }.count
                let mine = reactions.contains { $0.emoji == e.rawValue && $0.userId == myUserId }
                Button {
                    guard !busy else { return }
                    Task { busy = true; await onTap(e.rawValue); busy = false }
                } label: {
                    VStack(spacing: 2) {
                        Text(e.glyph).font(.title2)
                        if count > 0 { Text("\(count)").font(.caption2).foregroundStyle(.secondary) }
                    }
                    .padding(.vertical, 4).padding(.horizontal, 8)
                    .background(mine ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.clear),
                                in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .disabled(busy)
    }
}

// MARK: - 5.6 Team 计划浏览 + Fork

struct TeamPlansView: View {
    @Environment(TeamService.self) private var teamService
    @Environment(SyncEngine.self) private var syncEngine

    let team: TeamDTO
    @State private var plans: [ServerPlanDTO] = []
    @State private var error: String?
    @State private var toast: String?
    @State private var forking: UUID?

    var body: some View {
        List {
            if plans.isEmpty {
                Text("还没有成员发布计划").foregroundStyle(.secondary)
            }
            ForEach(plans) { p in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name)
                        Text("\(p.itemCount) 个动作").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task { await fork(p) }
                    } label: {
                        if forking == p.id { ProgressView() }
                        else { Label("Fork", systemImage: "arrow.triangle.branch") }
                    }
                    .buttonStyle(.bordered)
                    .disabled(forking != nil)
                }
            }
        }
        .navigationTitle("Team 计划")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .refreshable { await reload() }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast).font(.callout).padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule()).padding(.bottom, 24)
                    .transition(.opacity)
            }
        }
        .alert("出错了", isPresented: .constant(error != nil)) {
            Button("好") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func reload() async {
        do { plans = try await teamService.plans(of: team.id) }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
    }

    private func fork(_ p: ServerPlanDTO) async {
        forking = p.id; defer { forking = nil }
        do {
            try await teamService.fork(planId: p.id)
            // 副本归属自己，跑一次同步把它拉回本地「我的计划」。
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
