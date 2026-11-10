import Foundation
import SwiftData

/// 会话与登录态。JWT 存 Keychain；当前用户落 SwiftData（UserProfile）。
/// 首登 Apple 才返回邮箱/姓名，必须在首登时落地保存。
@MainActor
@Observable
final class SessionStore {
    private static let tokenKey = "jwt"

    private(set) var token: String?
    private(set) var currentUserId: UUID?

    /// 首登补全门控信号：后端画像称呼是否为空。
    /// nil = 尚未拉取 `GET /me`（未知）；true = 需补全；false = 已补全。RootView 据此决定路由。
    private(set) var needsProfileCompletion: Bool?
    private(set) var profileLoadFailed = false
    @ObservationIgnored private var sessionGeneration = 0
    @ObservationIgnored private var resolvingProfileGeneration: Int?
    @ObservationIgnored private var profileEditRevision = 0
    @ObservationIgnored private var pushingProfileGeneration: Int?
    @ObservationIgnored var onSessionInvalidated: () -> Void = {}
    private(set) var requiresLocalCleanup: Bool
    private(set) var localCleanupFailed = false
    static let localCleanupPendingKey = "session.localCleanupPending"

    /// 画像上行待重试标记：乐观本地写后 PATCH 失败时置位，下次 refreshProfile 补传。
    private static let pushPendingKey = "profile.pushPending"

    /// 重装/全新安装检测哨兵：iOS Keychain 跨「删除重装」存活，而 UserDefaults 随重装清空。
    /// 故「哨兵缺失」恰等价于「重装/全新安装首启」。
    private static let launchedBeforeKey = "session.hasLaunchedBefore"

    private let modelContext: ModelContext
    private let profileDefaults: UserDefaults
    private let loadProfile: () async throws -> ProfileDTO
    private let writeProfile: (ProfilePatchRequest) async throws -> ProfileDTO

    init(modelContext: ModelContext,
         profileDefaults: UserDefaults = .standard,
         loadProfile: @escaping () async throws -> ProfileDTO = { try await ProfileAPI.me() },
         updateProfile: @escaping (ProfilePatchRequest) async throws -> ProfileDTO = { try await ProfileAPI.update($0) }) {
        self.modelContext = modelContext
        self.profileDefaults = profileDefaults
        self.loadProfile = loadProfile
        self.writeProfile = updateProfile
        self.requiresLocalCleanup = profileDefaults.bool(forKey: Self.localCleanupPendingKey)
        // 删除重装 = 干净重来：重装首启先清掉残留 Keychain JWT，使重装后回登录页重新 Apple 登录，
        // 而非以孤儿 token 误判为已登录（会跳过登录、且因本地数据已清空而误弹补全页，甚至失效 token 死锁）。
        Self.clearOrphanTokenOnFreshInstall()
        self.token = Keychain.get(Self.tokenKey)
        if requiresLocalCleanup {
            Keychain.delete(Self.tokenKey)
            self.token = nil
        }
        // 重启后 handleLogin 不会再走一遍。currentUserId 直接从 JWT 的 sub 解出（与 token 同生命周期），
        // 避免 SwiftData 档案被清空（如开发期重装 App）导致 token 在、currentUserId 却为 nil 的 desync。
        if let token {
            self.currentUserId = Self.userId(fromJWT: token)
                ?? ((try? modelContext.fetch(FetchDescriptor<UserProfile>()))?.first?.serverUserId)
        }
        // provider 直接读 Keychain：线程安全且非 actor 隔离，避免捕获 MainActor 状态。
        let key = Self.tokenKey
        let tokenSnapshot = self.token
        Task { [weak self] in
            #if DEBUG
            // UI 测试模式由 uitestInjectFakeSession 独占安装 hooks，跳过避免竞态覆盖。
            if UITestHooks.isLiveWorkoutUITest || UITestHooks.isAutoLogin { return }
            #endif
            await self?.installAPIHooks(tokenKey: key, tokenSnapshot: tokenSnapshot)
        }
    }

    /// 重装/全新安装首启清除孤儿 token：哨兵缺失即重装首启，删 Keychain JWT 后置位哨兵；
    /// 正常重启（哨兵已置位）则原样保留登录态。
    private static func clearOrphanTokenOnFreshInstall() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: launchedBeforeKey) else { return }
        Keychain.delete(tokenKey)
        defaults.set(true, forKey: launchedBeforeKey)
    }

    var isLoggedIn: Bool { token != nil }

    /// 登录成功：存 token + upsert 本地用户档案（首登写入 email/姓名，Apple 全名作补全页预填）。
    /// 随后异步拉 `GET /me` 回灌并刷新首登门控信号（needsProfileCompletion）。
    func handleLogin(_ auth: AuthResponse, appleSub: String?, email: String?, displayName: String?) async {
        guard !requiresLocalCleanup else { return }
        resetProfileResolution()
        Keychain.set(auth.token, for: Self.tokenKey)
        self.token = auth.token
        self.currentUserId = auth.userId
        upsertProfile(userId: auth.userId, appleSub: appleSub, email: email, displayName: displayName)
        await installAPIHooks(tokenKey: Self.tokenKey, tokenSnapshot: auth.token)
        Task { await refreshProfile() }
    }

    func logout() {
        resetProfileResolution()
        if let currentUserId {
            TeamService.clearStoredShareState(userId: currentUserId)
        }
        Keychain.delete(Self.tokenKey)
        token = nil
        currentUserId = nil
        Task { await installAPIHooks(tokenKey: Self.tokenKey, tokenSnapshot: nil) }
        // 清门控：避免再次登录时 refreshProfile 返回前残留上次会话的判定值导致路由闪烁。
        needsProfileCompletion = nil
    }

    /// 服务端删号成功后先持久化未完成标记并退出认证；RootView 移除旧页面后执行清理。
    func beginDeletedAccountCleanup() {
        profileDefaults.set(true, forKey: Self.localCleanupPendingKey)
        requiresLocalCleanup = true
        localCleanupFailed = false
        logout()
    }

    @discardableResult
    func retryLocalCleanup(persist: (ModelContext) throws -> Void = { try LocalModelSave.save($0) }) -> Bool {
        guard requiresLocalCleanup else { return true }
        do {
            try LocalAccountCleanup.perform(in: modelContext, persist: persist)
            SyncDomain.resetAllWatermarks(in: profileDefaults)
            setPushPending(false)
            profileDefaults.removeObject(forKey: Self.localCleanupPendingKey)
            localCleanupFailed = false
            requiresLocalCleanup = false
            return true
        } catch {
            localCleanupFailed = true
            return false
        }
    }

    /// 从自有 JWT 的 payload.sub 解出 userId（后端 JwtService 以 sub = userId 签发）。base64url 需补位。
    static func userId(fromJWT token: String) -> UUID? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var b64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String else { return nil }
        return UUID(uuidString: sub)
    }

    /// 取当前用户档案；若因 desync（token 在、SwiftData 档案被清空，如开发期重装 App）缺失，
    /// 则按 currentUserId 懒补建一份最小档案。避免「currentUserId 有值却查不到 UserProfile」
    /// 导致依赖档案的本地写入（如性别切换）静默失败。
    @discardableResult
    func ensureProfile() -> UserProfile? {
        guard !requiresLocalCleanup, let userId = currentUserId else { return nil }
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.serverUserId == userId }
        )
        if let existing = try? modelContext.fetch(descriptor).first { return existing }
        let profile = UserProfile(serverUserId: userId, appleSub: "")
        modelContext.insert(profile)
        try? LocalModelSave.save(modelContext)
        return profile
    }

    private func upsertProfile(userId: UUID, appleSub: String?, email: String?, displayName: String?) {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.serverUserId == userId }
        )
        let existing = try? modelContext.fetch(descriptor).first
        if let existing {
            // 后续登录 Apple 不再回邮箱，只在有新值时覆盖，避免把首登邮箱清空。
            if let email { existing.email = email }
            if let displayName { existing.displayName = displayName }
        } else {
            let profile = UserProfile(
                serverUserId: userId,
                appleSub: appleSub ?? "",
                email: email,
                displayName: displayName
            )
            modelContext.insert(profile)
        }
        try? LocalModelSave.save(modelContext)
    }

    // MARK: - 画像（GET /me 回灌 + PATCH 上行，服务端权威域）

    /// 画像未知时有限重试；延迟可在隔离测试中置零。
    func resolveProfile(retryDelay: Duration = .seconds(2)) async {
        let generation = sessionGeneration
        guard isLoggedIn, needsProfileCompletion == nil,
              resolvingProfileGeneration != generation else { return }
        resolvingProfileGeneration = generation
        profileLoadFailed = false
        defer {
            if resolvingProfileGeneration == generation { resolvingProfileGeneration = nil }
        }
        for attempt in 0..<5 {
            guard sessionGeneration == generation, isLoggedIn,
                  needsProfileCompletion == nil, !Task.isCancelled else { return }
            await refreshProfile()
            guard sessionGeneration == generation, isLoggedIn,
                  needsProfileCompletion == nil, !Task.isCancelled else { return }
            if attempt < 4 {
                do { try await Task.sleep(for: retryDelay) }
                catch { return }
            }
        }
        profileLoadFailed = true
    }

    private func resetProfileResolution() {
        onSessionInvalidated()
        sessionGeneration += 1
        resolvingProfileGeneration = nil
        profileLoadFailed = false
        needsProfileCompletion = nil
    }

    /// 登录后 / 冷启动后拉后端画像并回灌本地，刷新首登门控信号。
    /// 先补传上次失败的本地改动（避免随后回灌用服务端旧值覆盖本地未同步改动），
    /// 仅在无待传时才以服务端值为准。失败（离线）保持本地、门控按本地称呼兜底判定。
    func refreshProfile() async {
        let generation = sessionGeneration
        await installAPIHooks(tokenKey: Self.tokenKey, tokenSnapshot: token)
        guard sessionGeneration == generation, isLoggedIn, !Task.isCancelled else { return }
        let flushed = await flushPendingProfilePush()
        guard sessionGeneration == generation, isLoggedIn, !Task.isCancelled else { return }
        guard flushed else {
            // 仍有待传：保留本地、不拉服务端以免覆盖。本地有称呼则放行（离线优先），
            // 无称呼也不误判为「需补全」（保持门控不动，停在加载态重试）。
            if !localDisplayNameMissing() { needsProfileCompletion = false }
            return
        }
        do {
            let editRevision = profileEditRevision
            let dto = try await loadProfile()
            guard sessionGeneration == generation, isLoggedIn, !Task.isCancelled else { return }
            guard editRevision == profileEditRevision, !profileDefaults.bool(forKey: Self.pushPendingKey) else {
                if !localDisplayNameMissing() { needsProfileCompletion = false }
                return
            }
            reconcile(dto)
            // 唯一判定真相：GET /me 成功且后端称呼为空 = 需补全。
            needsProfileCompletion = (dto.displayName ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        } catch APIError.http(status: 404, body: _) {
            guard sessionGeneration == generation, !Task.isCancelled else { return }
            // JWT 仍有效但账号已不存在（如本地更换测试库），继续重试无法恢复会话。
            logout()
        } catch APIError.unauthorized {
            // 401 已由全局处理器触发登出回登录页；此处不动门控（即将离开本视图）。
            return
        } catch {
            guard sessionGeneration == generation, isLoggedIn, !Task.isCancelled else { return }
            // GET /me 失败（网络/超时）：严格区分「拿不到服务端数据」与「确认无名字」。
            // 本地已有称呼（正常离线重启）→ 放行进主 App，离线优先；
            // 本地无称呼（罕见：有 token 但 SwiftData 为空且离线）→ 不置 true，保持门控不动停在加载态重试，
            // 绝不把「拉取失败」误判成「用户未填称呼」而弹补全页。
            if !localDisplayNameMissing() { needsProfileCompletion = false }
        }
    }

    /// 首登补全提交：乐观本地写 + PATCH（必须成功才算补全）。成功后清门控。
    /// 失败抛出供页面提示重试；本地已写入的值保留。
    func submitProfileCompletion(displayName: String, sex: BodySex,
                                 persist: (ModelContext) throws -> Void = { try LocalModelSave.save($0) }) async throws {
        let generation = sessionGeneration
        let name = displayName.trimmingCharacters(in: .whitespaces)
        guard let profile = ensureProfile() else { throw APIError.unauthorized }
        _ = profile.serverUserId
        try LocalModelCommit.perform(in: modelContext, persist: persist) {
            profile.displayName = name
            profile.sex = sex
        }

        let patch = ProfilePatchRequest(displayName: name, sex: sex.rawValue)
        let dto = try await writeProfile(patch)
        guard sessionGeneration == generation, isLoggedIn, !Task.isCancelled else { throw CancellationError() }
        reconcile(dto)
        setPushPending(false)
        needsProfileCompletion = false
    }

    func saveDisplayName(_ name: String,
                         persist: (ModelContext) throws -> Void = { try LocalModelSave.save($0) }) throws {
        try saveProfileChange(persist: persist) { $0.displayName = name.trimmingCharacters(in: .whitespaces) }
    }

    func saveSex(_ sex: BodySex,
                 persist: (ModelContext) throws -> Void = { try LocalModelSave.save($0) }) throws {
        try saveProfileChange(persist: persist) { $0.sex = sex }
    }

    private func saveProfileChange(persist: (ModelContext) throws -> Void,
                                   mutation: (UserProfile) -> Void) throws {
        guard let profile = ensureProfile() else { throw APIError.unauthorized }
        _ = profile.serverUserId
        try LocalModelCommit.perform(in: modelContext, persist: { context in
            #if DEBUG
            try UITestHooks.failFirstSaveIfNeeded("profile")
            #endif
            try persist(context)
        }) { mutation(profile) }
        scheduleProfilePush()
    }

    /// 我的页二次编辑：调用方已乐观写本地 UserProfile 并 save，此处把当前本地画像 PATCH 上行。
    /// 失败置 pending、静默重试（不抛错、不阻塞 UI）。
    func scheduleProfilePush() {
        profileEditRevision += 1
        setPushPending(true)
        Task { await flushPendingProfilePush() }
    }

    /// 补传待同步的本地画像（全量 PATCH 令服务端向本地收敛）。无待传或成功返回 true。
    @discardableResult
    func flushPendingProfilePush() async -> Bool {
        let generation = sessionGeneration
        guard profileDefaults.bool(forKey: Self.pushPendingKey) else { return true }
        guard pushingProfileGeneration != generation else { return false }
        pushingProfileGeneration = generation
        defer { if pushingProfileGeneration == generation { pushingProfileGeneration = nil } }
        while profileDefaults.bool(forKey: Self.pushPendingKey) {
            guard sessionGeneration == generation, isLoggedIn, !Task.isCancelled else { return false }
            guard let profile = currentProfile() else { return true }
            let revision = profileEditRevision
            let name = (profile.displayName ?? "").trimmingCharacters(in: .whitespaces)
            let patch = ProfilePatchRequest(displayName: name.isEmpty ? nil : name, sex: profile.sex.rawValue)
            do {
                let dto = try await writeProfile(patch)
                guard sessionGeneration == generation, isLoggedIn, !Task.isCancelled else { return false }
                // 新编辑排在当前请求之后发送；旧响应不覆盖新值、不清掉它的待传标记。
                guard revision == profileEditRevision else { continue }
                reconcile(dto)
                setPushPending(false)
                return true
            } catch { return false }
        }
        return true
    }

    /// 以服务端画像回灌本地。服务端权威；但称呼/性别为空时保留本地
    /// （称呼空 = 未补全，保留 Apple 预填供补全页；性别空 = 未设置，保留本地默认）。
    private func reconcile(_ dto: ProfileDTO) {
        guard let profile = ensureProfile() else { return }
        if let name = dto.displayName, !name.trimmingCharacters(in: .whitespaces).isEmpty {
            profile.displayName = name
        }
        if let s = dto.sex, let bodySex = BodySex(rawValue: s) {
            profile.sex = bodySex
        }
        if let email = dto.email { profile.email = email }
        try? LocalModelSave.save(modelContext)
    }

    private func currentProfile() -> UserProfile? {
        guard let userId = currentUserId else { return nil }
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.serverUserId == userId }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func localDisplayNameMissing() -> Bool {
        (currentProfile()?.displayName ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func setPushPending(_ pending: Bool) {
        profileDefaults.set(pending, forKey: Self.pushPendingKey)
    }

    private func installAPIHooks(tokenKey: String, tokenSnapshot: String?) async {
        await APIClient.shared.setTokenProvider { Keychain.get(tokenKey) ?? tokenSnapshot }
        // 全局 401 → 登出回登录页（token 失效/过期时兜底，含把人困在补全页的失效 token）。
        await APIClient.shared.setUnauthorizedHandler { [weak self] in
            guard let session = self else { return }
            Task { @MainActor in session.logout() }
        }
    }
}

#if DEBUG
extension SessionStore {
    /// UI 测试（-uitest-live-workout）：无签名模拟器 build 写 Keychain 会 errSecMissingEntitlement(-34018)，
    /// 故直接注入内存登录态 + 本地画像（含称呼），并置位补全门控跳过 GET /me 路由请求。
    /// token provider 返回常量假 token（不读 Keychain）；401 handler 置空——测试期间任何请求失败都不登出。
    func uitestInjectFakeSession(profileResolved: Bool = true) {
        guard !requiresLocalCleanup else { return }
        resetProfileResolution()
        let userId = UUID()
        let token = "uitest-fake-token"
        self.token = token
        self.currentUserId = userId
        upsertProfile(userId: userId, appleSub: "uitest", email: nil,
                      displayName: profileResolved ? "测试用户" : nil)
        needsProfileCompletion = profileResolved ? false : nil
        Task {
            await APIClient.shared.setTokenProvider { token }
            await APIClient.shared.setUnauthorizedHandler { }
        }
    }
}
#endif
