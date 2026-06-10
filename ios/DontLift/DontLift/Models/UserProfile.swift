import Foundation
import SwiftData

/// 本地持久化的登录用户。
/// Apple 仅首登返回邮箱/姓名，必须落地保存（design.md 身份模型 / 风险项）。
/// JWT/refresh 等密钥不入 SwiftData，存 Keychain。
@Model
final class UserProfile {
    /// 服务端 user.id（业务主体三层模型的主键）。
    @Attribute(.unique) var serverUserId: UUID
    /// Apple 身份标识 sub（provider_user_id）。
    var appleSub: String
    /// 首登保存的邮箱，可能为中转邮箱。
    var email: String?
    var displayName: String?
    var createdAt: Date

    init(
        serverUserId: UUID,
        appleSub: String,
        email: String? = nil,
        displayName: String? = nil,
        createdAt: Date = .now
    ) {
        self.serverUserId = serverUserId
        self.appleSub = appleSub
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
    }
}
