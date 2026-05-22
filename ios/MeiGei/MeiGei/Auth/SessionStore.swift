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
        // 重启后 handleLogin 不会再走一遍，从持久化档案恢复当前用户 id（区分「我」用）。
        if token != nil {
            let profiles = (try? modelContext.fetch(FetchDescriptor<UserProfile>())) ?? []
            self.currentUserId = profiles.first?.serverUserId
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
