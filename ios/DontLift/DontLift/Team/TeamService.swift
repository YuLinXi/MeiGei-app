import Foundation

/// Team 域 API 封装。Team 数据以服务端为准（design.md D7），不进 SwiftData，
/// 由视图按需拉取持有。打卡/表情走「进页面拉取 + APNs 提醒」的轻实时模型（D6）。
@MainActor
@Observable
final class TeamService {
    private let api: APIClient
    private static let legacyPendingShareKey = "dontlift.team.pendingCheckinShares"
    private static func pendingShareKey(userId: UUID) -> String {
        "dontlift.team.pendingCheckinShares.\(userId.uuidString)"
    }
    private static func pendingPlanShareEventKey(userId: UUID) -> String {
        "dontlift.team.pendingPlanShareEvents.\(userId.uuidString)"
    }
    private static func autoShareCacheKey(userId: UUID) -> String {
        "dontlift.team.autoShareTeamIds.\(userId.uuidString)"
    }
    static func clearStoredShareState(userId: UUID) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: pendingShareKey(userId: userId))
        defaults.removeObject(forKey: pendingPlanShareEventKey(userId: userId))
        defaults.removeObject(forKey: autoShareCacheKey(userId: userId))
        defaults.removeObject(forKey: legacyPendingShareKey)
    }
    private(set) var teams: [TeamDTO] = []

    /// 退出/解散成功后由详情页写入，返回 Team 列表时顶部 toast 读取并清空（跨页结果反馈）。
    var pendingActionToast: String?

    init(api: APIClient = .shared) {
        self.api = api
        // b8 前的队列未按 userId 隔离；升级后直接丢弃，避免跨账号重放旧摘要。
        UserDefaults.standard.removeObject(forKey: Self.legacyPendingShareKey)
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

    func mySharePreferences(cacheFor userId: UUID? = nil) async throws -> [TeamMemberDTO] {
        let preferences: [TeamMemberDTO] = try await api.send("GET", "/teams/members/me/share-preferences")
        if let userId {
            cacheAutoShareTeamIds(preferences.filter(\.autoShareWorkouts).map(\.teamId), userId: userId)
        }
        return preferences
    }

    @discardableResult
    func updateAutoShareWorkouts(teamId: UUID, enabled: Bool, userId: UUID? = nil) async throws -> TeamMemberDTO {
        let member: TeamMemberDTO = try await api.send("PATCH", "/teams/\(teamId)/members/me/share-preferences",
                                                       body: UpdateTeamSharePreferenceRequest(autoShareWorkouts: enabled))
        if let userId {
            updateCachedAutoShareTeamId(teamId, enabled: enabled, userId: userId)
        }
        return member
    }

    func rememberAutoSharePreference(teamId: UUID, enabled: Bool, userId: UUID) {
        updateCachedAutoShareTeamId(teamId, enabled: enabled, userId: userId)
    }

    func leave(_ teamId: UUID) async throws {
        try await api.sendVoid("DELETE", "/teams/\(teamId)/members/me")
        try await loadMyTeams()
    }

    func dissolve(_ teamId: UUID) async throws {
        try await api.sendVoid("DELETE", "/teams/\(teamId)")
        try await loadMyTeams()
    }

    // MARK: - 计划模板：浏览 / 分享 / Fork / 反馈

    func plans(of teamId: UUID) async throws -> [ServerPlanDTO] {
        try await api.send("GET", "/teams/\(teamId)/plans")
    }

    func planShares(of teamId: UUID) async throws -> [TeamPlanShareCardDTO] {
        try await api.send("GET", "/teams/\(teamId)/plan-shares")
    }

    @discardableResult
    func share(planId: UUID, to teamId: UUID, idempotencyToken: String? = nil) async throws -> TeamPlanShareVersionDTO {
        let token = idempotencyToken ?? UUID().uuidString
        return try await api.send("POST", "/teams/\(teamId)/plan-shares",
                                  body: SharePlanRequest(sourcePlanId: planId,
                                                         planNameSnapshot: nil,
                                                         items: nil),
                                  idempotencyKey: "team-plan-share-\(teamId.uuidString):\(planId.uuidString):\(token)")
    }

    @discardableResult
    func share(plan: WorkoutPlan, to teamId: UUID, idempotencyToken: String? = nil) async throws -> TeamPlanShareVersionDTO {
        let token = idempotencyToken ?? String(plan.updatedAt.timeIntervalSince1970)
        return try await api.send("POST", "/teams/\(teamId)/plan-shares",
                                  body: SharePlanRequest(sourcePlanId: plan.localId,
                                                         planNameSnapshot: plan.name,
                                                         items: Self.weightlessItemsJSON(from: plan)),
                                  idempotencyKey: "team-plan-share-\(teamId.uuidString):\(plan.localId.uuidString):\(token)")
    }

    func publish(planId: UUID, to teamId: UUID) async throws {
        let _: TeamPlanShareVersionDTO = try await share(planId: planId, to: teamId)
    }

    func deletePlanShare(_ shareId: UUID, in teamId: UUID) async throws {
        try await api.sendVoid("DELETE", "/teams/\(teamId)/plan-shares/\(shareId)",
                               idempotencyKey: "team-plan-share-delete-\(shareId.uuidString):\(UUID().uuidString)")
    }

    /// Fork 队友模板为自己的副本（服务端复制 jsonb）。返回新副本 id；
    /// 调用方随后跑一次同步把副本拉回本地 SwiftData。
    @discardableResult
    func fork(planId: UUID) async throws -> ServerPlanDTO {
        try await api.send("POST", "/teams/plans/\(planId)/fork",
                           idempotencyKey: "team-plan-fork-\(planId.uuidString)")
    }

    @discardableResult
    func forkShareVersion(_ versionId: UUID) async throws -> ServerPlanDTO {
        try await api.send("POST", "/teams/plan-share-versions/\(versionId)/fork",
                           idempotencyKey: "team-plan-share-fork-\(versionId.uuidString)")
    }

    @discardableResult
    func recordPlanShareEvent(versionId: UUID,
                              eventType: String,
                              workoutId: UUID? = nil,
                              eventDate: Date? = nil,
                              idempotencyKey: String? = nil) async throws -> TeamPlanShareEventDTO {
        let eventDateText = eventDate.map(Self.dateOnly)
        let key = idempotencyKey ?? Self.planShareEventIdempotencyKey(versionId: versionId,
                                                                      eventType: eventType,
                                                                      workoutId: workoutId,
                                                                      eventDate: eventDateText)
        return try await api.send("POST", "/teams/plan-share-versions/\(versionId)/events",
                                  body: TeamPlanShareEventRequest(eventType: eventType,
                                                                  workoutId: workoutId,
                                                                  eventDate: eventDateText),
                                  idempotencyKey: key)
    }

    func recordPlanShareEventOrQueue(versionId: UUID,
                                     eventType: String,
                                     workoutId: UUID? = nil,
                                     eventDate: Date? = nil,
                                     userId: UUID?) async {
        guard let userId else { return }
        let intent = PendingPlanShareEvent(versionId: versionId,
                                           eventType: eventType,
                                           workoutId: workoutId,
                                           eventDate: eventDate.map(Self.dateOnly))
        enqueue(intent, userId: userId)
        do {
            _ = try await send(intent)
            removePending(intent, userId: userId)
        } catch where error.isCancellationError {
            return
        } catch where shouldQueuePlanShareEventRetry(error) {
            // 已在请求前落盘，保留待下轮同步后重试。
        } catch {
            // 反馈统计是低打扰能力，权限/参数错误不反复提示用户。
            removePending(intent, userId: userId)
        }
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

    func checkinHistory(teamId: UUID, month: Date) async throws -> TeamCheckinFeedDTO {
        try await api.send("GET", "/teams/\(teamId)/checkins/history",
                           query: [URLQueryItem(name: "month", value: Self.monthOnly(month))])
    }

    func reactions(checkinId: UUID) async throws -> [CheckinReactionDTO] {
        try await api.send("GET", "/checkins/\(checkinId)/reactions")
    }

    /// 单选·可取消：服务端按 (checkin,user) 唯一切换；再点同一个表情时服务端删除并返回空 body，故用 sendVoid。
    /// 调用方点击后会回拉 reactions(checkinId:) 拿真实状态，无需解析返回。
    func react(checkinId: UUID, emoji: String) async throws {
        try await api.sendVoid("POST", "/checkins/\(checkinId)/reactions",
                               body: ReactRequest(emoji: emoji),
                               idempotencyKey: "checkin-reaction-\(checkinId.uuidString):\(emoji):\(UUID().uuidString)")
    }

    /// 训练完成后的显式分享：仅写入用户选择的 Team。空数组表示「仅自己可见」，不发请求。
    @discardableResult
    func checkIn(workout: Workout, teamIds: [UUID]) async throws -> [TeamCheckinDTO] {
        try await checkIn(draft: TeamShareDraft(workout: workout), teamIds: teamIds)
    }

    @discardableResult
    func checkIn(draft: TeamShareDraft, teamIds: [UUID]) async throws -> [TeamCheckinDTO] {
        guard !teamIds.isEmpty else { return [] }
        let body = CheckInRequest(workoutId: draft.workoutId,
                                  checkinDate: draft.checkinDate,
                                  summary: draft.summary,
                                  teamIds: teamIds)
        // 幂等键含 updatedAt：首次打卡去重；编辑训练后 updatedAt 变化 → 新键穿透幂等过滤，
        // 后端按 (team,user,workout) 更新摘要快照。
        return try await api.send("POST", "/checkins", body: body,
                                  idempotencyKey: "checkin-\(draft.workoutId.uuidString):\(draft.updatedAt.timeIntervalSince1970)")
    }

    /// 显式分享；失败时把用户已确认的分享意图持久化，待后续同步完成后重试。
    func shareOrQueue(draft: TeamShareDraft, teamIds: [UUID], userId: UUID?) async -> TeamShareResult {
        guard !teamIds.isEmpty else { return .privateOnly }
        guard let userId else { return .failed("登录状态已失效") }
        let intent = PendingCheckinShare(draft: draft, teamIds: teamIds)
        guard draft.isWorkoutSynced else {
            enqueue(intent, userId: userId)
            return .queued
        }
        do {
            let checkins = try await send(intent)
            removePending(intent, userId: userId)
            return .shared(count: checkins.count)
        } catch where error.isCancellationError {
            return .cancelled
        } catch where shouldQueueShareRetry(error) {
            enqueue(intent, userId: userId)
            return .queued
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// 训练完成后的低打扰自动分享：只读取用户已在 Team 内开启的偏好。
    func autoShareOrQueue(draft: TeamShareDraft, userId: UUID?) async -> TeamShareResult {
        guard let userId else { return .privateOnly }
        do {
            let enabledTeamIds = try await mySharePreferences(cacheFor: userId)
                .filter(\.autoShareWorkouts)
                .map(\.teamId)
            guard !enabledTeamIds.isEmpty else { return .privateOnly }
            return await shareOrQueue(draft: draft, teamIds: enabledTeamIds, userId: userId)
        } catch where error.isCancellationError {
            return .cancelled
        } catch APIError.transport {
            let cachedTeamIds = cachedAutoShareTeamIds(userId: userId)
            guard !cachedTeamIds.isEmpty else { return .privateOnly }
            return await shareOrQueue(draft: draft, teamIds: cachedTeamIds, userId: userId)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func withdrawCheckin(teamId: UUID, workoutId: UUID) async throws {
        try await api.sendVoid("DELETE", "/teams/\(teamId)/checkins/workouts/\(workoutId)")
    }

    /// workout 同步成功后由 MainTab 触发：只重放当前用户、且本地 workout 已处于 synced 的分享意图。
    func retryPendingShares(userId: UUID, syncedDrafts: [UUID: TeamShareDraft]) async {
        let intents = pendingShares(userId: userId)
        guard !intents.isEmpty else { return }
        for intent in intents {
            guard let currentDraft = syncedDrafts[intent.workoutId] else { continue }
            let readyIntent = intent.matches(currentDraft)
                ? intent
                : PendingCheckinShare(draft: currentDraft, teamIds: intent.teamIds)
            do {
                _ = try await send(readyIntent)
                removePending(intent, userId: userId)
                removePending(readyIntent, userId: userId)
            } catch where error.isCancellationError {
                return
            } catch where shouldQueueShareRetry(error) {
                replacePending(intent, with: readyIntent, userId: userId)
            } catch {
                // 保留待下轮同步后重试。
            }
        }
    }

    func pendingShareWorkoutIds(userId: UUID) -> Set<UUID> {
        Set(pendingShares(userId: userId).map(\.workoutId))
    }

    func hasPendingPlanShareEvents(userId: UUID) -> Bool {
        !pendingPlanShareEvents(userId: userId).isEmpty
    }

    func pendingPlanShareEventWorkoutIds(userId: UUID) -> Set<UUID> {
        Set(pendingPlanShareEvents(userId: userId).compactMap(\.workoutId))
    }

    func retryPendingPlanShareEvents(userId: UUID, syncedWorkoutIds: Set<UUID>) async {
        let intents = pendingPlanShareEvents(userId: userId)
        guard !intents.isEmpty else { return }
        for intent in intents {
            if let workoutId = intent.workoutId, !syncedWorkoutIds.contains(workoutId) {
                continue
            }
            do {
                _ = try await send(intent)
                removePending(intent, userId: userId)
            } catch where error.isCancellationError {
                return
            } catch where shouldQueuePlanShareEventRetry(error) {
                // 保留待下轮同步后重试。
            } catch {
                removePending(intent, userId: userId)
            }
        }
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

    private static let monthOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM"
        return f
    }()

    static func monthOnly(_ date: Date) -> String { monthOnlyFormatter.string(from: date) }

    private static func planShareEventIdempotencyKey(versionId: UUID,
                                                     eventType: String,
                                                     workoutId: UUID?,
                                                     eventDate: String?) -> String {
        let identity = workoutId?.uuidString ?? eventDate ?? UUID().uuidString
        return "team-plan-share-event-\(versionId.uuidString):\(eventType):\(identity)"
    }

    static func weightlessItemsJSON(from plan: WorkoutPlan) -> String {
        let items = plan.items.map {
            PlanItem(itemId: $0.itemId,
                     builtinExerciseCode: $0.builtinExerciseCode,
                     customExerciseId: $0.customExerciseId,
                     exerciseName: $0.exerciseName,
                     primaryMuscle: $0.primaryMuscle,
                     equipmentType: $0.equipmentType,
                     orderIndex: $0.orderIndex,
                     suggestedSets: $0.suggestedSets,
                     suggestedReps: $0.suggestedReps,
                     suggestedWeightKg: nil)
        }
        return (try? String(data: JSONCoding.encoder.encode(items), encoding: .utf8)) ?? "[]"
    }

    private func send(_ intent: PendingCheckinShare) async throws -> [TeamCheckinDTO] {
        let body = CheckInRequest(workoutId: intent.workoutId,
                                  checkinDate: intent.checkinDate,
                                  summary: intent.summary,
                                  teamIds: intent.teamIds)
        return try await api.send("POST", "/checkins", body: body,
                                  idempotencyKey: intent.idempotencyKey)
    }

    private func send(_ intent: PendingPlanShareEvent) async throws -> TeamPlanShareEventDTO {
        try await api.send("POST", "/teams/plan-share-versions/\(intent.versionId)/events",
                           body: TeamPlanShareEventRequest(eventType: intent.eventType,
                                                           workoutId: intent.workoutId,
                                                           eventDate: intent.eventDate),
                           idempotencyKey: intent.idempotencyKey)
    }

    private func pendingShares(userId: UUID) -> [PendingCheckinShare] {
        guard let data = UserDefaults.standard.data(forKey: Self.pendingShareKey(userId: userId)),
              let decoded = try? JSONCoding.decoder.decode([PendingCheckinShare].self, from: data) else {
            return []
        }
        return decoded
    }

    private func setPendingShares(_ items: [PendingCheckinShare], userId: UUID) {
        let data = try? JSONCoding.encoder.encode(items)
        UserDefaults.standard.set(data, forKey: Self.pendingShareKey(userId: userId))
    }

    private func enqueue(_ intent: PendingCheckinShare, userId: UUID) {
        var items = pendingShares(userId: userId).filter { $0.id != intent.id }
        items.append(intent)
        setPendingShares(items, userId: userId)
    }

    private func removePending(_ intent: PendingCheckinShare, userId: UUID) {
        setPendingShares(pendingShares(userId: userId).filter { $0.id != intent.id }, userId: userId)
    }

    private func replacePending(_ oldIntent: PendingCheckinShare, with newIntent: PendingCheckinShare, userId: UUID) {
        var items = pendingShares(userId: userId).filter { $0.id != oldIntent.id && $0.id != newIntent.id }
        items.append(newIntent)
        setPendingShares(items, userId: userId)
    }

    private func pendingPlanShareEvents(userId: UUID) -> [PendingPlanShareEvent] {
        guard let data = UserDefaults.standard.data(forKey: Self.pendingPlanShareEventKey(userId: userId)),
              let decoded = try? JSONCoding.decoder.decode([PendingPlanShareEvent].self, from: data) else {
            return []
        }
        return decoded
    }

    private func setPendingPlanShareEvents(_ items: [PendingPlanShareEvent], userId: UUID) {
        let data = try? JSONCoding.encoder.encode(items)
        UserDefaults.standard.set(data, forKey: Self.pendingPlanShareEventKey(userId: userId))
    }

    private func enqueue(_ intent: PendingPlanShareEvent, userId: UUID) {
        var items = pendingPlanShareEvents(userId: userId).filter { $0.id != intent.id }
        items.append(intent)
        setPendingPlanShareEvents(items, userId: userId)
    }

    private func removePending(_ intent: PendingPlanShareEvent, userId: UUID) {
        setPendingPlanShareEvents(pendingPlanShareEvents(userId: userId).filter { $0.id != intent.id }, userId: userId)
    }

    private func shouldQueueShareRetry(_ error: Error) -> Bool {
        if error.isCancellationError { return false }
        if case APIError.transport = error { return true }
        if case APIError.http(let status, let body) = error,
           status == 404,
           body.contains("训练尚未同步") {
            return true
        }
        return false
    }

    private func shouldQueuePlanShareEventRetry(_ error: Error) -> Bool {
        shouldQueueShareRetry(error)
    }

    private func cachedAutoShareTeamIds(userId: UUID) -> [UUID] {
        guard let data = UserDefaults.standard.data(forKey: Self.autoShareCacheKey(userId: userId)),
              let ids = try? JSONCoding.decoder.decode([UUID].self, from: data) else {
            return []
        }
        return ids
    }

    private func cacheAutoShareTeamIds(_ teamIds: [UUID], userId: UUID) {
        let sorted = teamIds.sorted { $0.uuidString < $1.uuidString }
        let data = try? JSONCoding.encoder.encode(sorted)
        UserDefaults.standard.set(data, forKey: Self.autoShareCacheKey(userId: userId))
    }

    private func updateCachedAutoShareTeamId(_ teamId: UUID, enabled: Bool, userId: UUID) {
        var ids = cachedAutoShareTeamIds(userId: userId)
        if enabled {
            if !ids.contains(teamId) { ids.append(teamId) }
        } else {
            ids.removeAll { $0 == teamId }
        }
        cacheAutoShareTeamIds(ids, userId: userId)
    }
}

enum TeamShareResult: Equatable {
    case privateOnly
    case shared(count: Int)
    case queued
    case cancelled
    case failed(String)

    var shouldRequestSync: Bool {
        if case .queued = self { return true }
        return false
    }
}

private struct PendingCheckinShare: Codable, Identifiable, Equatable {
    var id: String
    var workoutId: UUID
    var checkinDate: String
    var summary: CheckinSummary
    var teamIds: [UUID]
    var updatedAt: Date

    init(draft: TeamShareDraft, teamIds: [UUID]) {
        let sortedTeamIds = teamIds.sorted { $0.uuidString < $1.uuidString }
        self.id = draft.workoutId.uuidString + ":" + sortedTeamIds.map(\.uuidString).joined(separator: ",") + ":\(draft.updatedAt.timeIntervalSince1970)"
        self.workoutId = draft.workoutId
        self.checkinDate = draft.checkinDate
        self.summary = draft.summary
        self.teamIds = sortedTeamIds
        self.updatedAt = draft.updatedAt
    }

    var idempotencyKey: String {
        "share-checkin-\(id)"
    }

    func matches(_ draft: TeamShareDraft) -> Bool {
        workoutId == draft.workoutId
        && checkinDate == draft.checkinDate
        && summary == draft.summary
    }
}

private struct PendingPlanShareEvent: Codable, Identifiable, Equatable {
    var id: String
    var versionId: UUID
    var eventType: String
    var workoutId: UUID?
    var eventDate: String?

    init(versionId: UUID, eventType: String, workoutId: UUID?, eventDate: String?) {
        self.versionId = versionId
        self.eventType = eventType
        self.workoutId = workoutId
        self.eventDate = eventDate
        let identity = workoutId?.uuidString ?? eventDate ?? "no-date"
        self.id = "\(versionId.uuidString):\(eventType):\(identity)"
    }

    var idempotencyKey: String {
        "team-plan-share-event-\(id)"
    }
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
