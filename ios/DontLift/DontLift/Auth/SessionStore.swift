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

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.token = Keychain.get(Self.tokenKey)
        // 重启后 handleLogin 不会再走一遍。currentUserId 直接从 JWT 的 sub 解出（与 token 同生命周期），
        // 避免 SwiftData 档案被清空（如开发期重装 App）导致 token 在、currentUserId 却为 nil 的 desync。
        if let token {
            self.currentUserId = Self.userId(fromJWT: token)
                ?? ((try? modelContext.fetch(FetchDescriptor<UserProfile>()))?.first?.serverUserId)
        }
        // provider 直接读 Keychain：线程安全且非 actor 隔离，避免捕获 MainActor 状态。
        let key = Self.tokenKey
        Task { await APIClient.shared.setTokenProvider { Keychain.get(key) } }
    }

    var isLoggedIn: Bool { token != nil }

    /// 登录成功：存 token + upsert 本地用户档案（首登写入 email/姓名）。
    func handleLogin(_ auth: AuthResponse, appleSub: String?, email: String?, displayName: String?) {
        Keychain.set(auth.token, for: Self.tokenKey)
        self.token = auth.token
        self.currentUserId = auth.userId
        upsertProfile(userId: auth.userId, appleSub: appleSub, email: email, displayName: displayName)
    }

    func logout() {
        Keychain.delete(Self.tokenKey)
        token = nil
        currentUserId = nil
    }

    /// 删号成功后：物理清空本地 SwiftData 全部用户数据 + 重置同步水位 + 清 Keychain JWT 并登出。
    /// 与「退出登录」不同——退出仅清登录态、保留本地数据，删号则不留任何残留。
    func wipeLocalDataAndLogout() {
        // 覆盖 AppModelContainer.schema 的全部 @Model 类型（新增模型时须同步补充）
        try? modelContext.delete(model: UserProfile.self)
        try? modelContext.delete(model: CustomExercise.self)
        try? modelContext.delete(model: WorkoutPlan.self)
        try? modelContext.delete(model: Workout.self)
        try? modelContext.delete(model: WorkoutExercise.self)
        try? modelContext.delete(model: WorkoutSet.self)
        try? modelContext.save()
        SyncDomain.resetAllWatermarks()
        logout()
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
        try? modelContext.save()
    }
}
