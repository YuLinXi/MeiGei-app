import Foundation

/// Team 域 API 封装。Team 数据以服务端为准（design.md D7），不进 SwiftData，
/// 由视图按需拉取持有。打卡/表情走「进页面拉取 + APNs 提醒」的轻实时模型（D6）。
@MainActor
@Observable
final class TeamService {
    private let api: APIClient
    private(set) var teams: [TeamDTO] = []

    /// 退出/解散成功后由详情页写入，返回 Team 列表时顶部 toast 读取并清空（跨页结果反馈）。
    var pendingActionToast: String?

    init(api: APIClient = .shared) {
        self.api = api
    }

    // MARK: - 空间与成员

    func loadMyTeams() async throws {
        teams = try await api.send("GET", "/teams")
    }

    func create(name: String) async throws -> TeamDTO {
        let team: TeamDTO = try await api.send("POST", "/teams", body: CreateTeamRequest(name: name))
        try await loadMyTeams()
        return team
    }

    func join(inviteCode: String) async throws -> TeamDTO {
        let team: TeamDTO = try await api.send("POST", "/teams/join",
                                               body: JoinTeamRequest(inviteCode: inviteCode))
        try await loadMyTeams()
        return team
    }

    func members(of teamId: UUID) async throws -> [TeamMemberDTO] {
        try await api.send("GET", "/teams/\(teamId)/members")
    }

    func leave(_ teamId: UUID) async throws {
        try await api.sendVoid("DELETE", "/teams/\(teamId)/members/me")
        try await loadMyTeams()
    }

    func dissolve(_ teamId: UUID) async throws {
        try await api.sendVoid("DELETE", "/teams/\(teamId)")
        try await loadMyTeams()
    }

    // MARK: - 计划模板：浏览 / 发布 / Fork

    func plans(of teamId: UUID) async throws -> [ServerPlanDTO] {
        try await api.send("GET", "/teams/\(teamId)/plans")
    }

    func publish(planId: UUID, to teamId: UUID) async throws {
        let _: ServerPlanDTO = try await api.send("POST", "/teams/\(teamId)/plans/\(planId)")
    }

    /// Fork 队友模板为自己的副本（服务端复制 jsonb）。返回新副本 id；
    /// 调用方随后跑一次同步把副本拉回本地 SwiftData。
    @discardableResult
    func fork(planId: UUID) async throws -> ServerPlanDTO {
        try await api.send("POST", "/teams/plans/\(planId)/fork")
    }

    // MARK: - 打卡 / 表情回应

    func checkins(teamId: UUID, date: Date = .now) async throws -> [TeamCheckinDTO] {
        try await api.send("GET", "/teams/\(teamId)/checkins",
                           query: [URLQueryItem(name: "date", value: Self.dateOnly(date))])
    }

    func checkinFeed(teamId: UUID, date: Date = .now) async throws -> TeamCheckinFeedDTO {
        try await api.send("GET", "/teams/\(teamId)/checkins/feed",
                           query: [URLQueryItem(name: "date", value: Self.dateOnly(date))])
    }

    func reactions(checkinId: UUID) async throws -> [CheckinReactionDTO] {
        try await api.send("GET", "/checkins/\(checkinId)/reactions")
    }

    /// 单选·可取消：服务端按 (checkin,user) 唯一切换；再点同一个表情时服务端删除并返回空 body，故用 sendVoid。
    /// 调用方点击后会回拉 reactions(checkinId:) 拿真实状态，无需解析返回。
    func react(checkinId: UUID, emoji: String) async throws {
        try await api.sendVoid("POST", "/checkins/\(checkinId)/reactions", body: ReactRequest(emoji: emoji))
    }

    /// 训练完成即打卡：fan-out 到本人所有 Team（无 Team 时服务端返回空，无副作用）。
    /// workoutId 用 localId（== serverId，软指针无 FK）。
    @discardableResult
    func checkIn(workout: Workout) async throws -> [TeamCheckinDTO] {
        let body = CheckInRequest(workoutId: workout.localId,
                                  checkinDate: Self.dateOnly(workout.startedAt),
                                  summary: CheckinSummary(workout: workout))
        // 幂等键含 updatedAt：首次打卡去重；编辑训练后 updatedAt 变化 → 新键穿透幂等过滤，
        // 后端按 (team,user,workout) 更新摘要快照。
        return try await api.send("POST", "/checkins", body: body,
                                  idempotencyKey: "checkin-\(workout.localId.uuidString):\(workout.updatedAt.timeIntervalSince1970)")
    }

    // MARK: - 工具

    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dateOnly(_ date: Date) -> String { dateOnlyFormatter.string(from: date) }
}

/// 4 个预设表情的展示映射（后端存 code，UI 显示 emoji）。
enum ReactionEmoji: String, CaseIterable, Identifiable {
    case muscle, fire, clap, heart
    var id: String { rawValue }
    var glyph: String {
        switch self {
        case .muscle: return "💪"
        case .fire: return "🔥"
        case .clap: return "👏"
        case .heart: return "❤️"
        }
    }
    static func glyph(for code: String) -> String {
        ReactionEmoji(rawValue: code)?.glyph ?? "❓"
    }
}
