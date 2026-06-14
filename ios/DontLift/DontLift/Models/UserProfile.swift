import Foundation
import SwiftData

/// 生理性别。仅用于切换肌群高亮图的人体底图轮廓（♀肩窄/腰收/髋宽/长发）。
/// 纯本地字段、不参与云同步（与 displayName/email 一致，profile 当前无同步域）。
enum BodySex: String, Codable, CaseIterable, Identifiable {
    case male
    case female

    var id: String { rawValue }
    var displayName: String { self == .male ? "男" : "女" }
}

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
    /// 生理性别（仅切高亮图底图，默认男）。SwiftData 新增属性带默认值，轻量迁移安全。
    var sex: BodySex = BodySex.male
    var createdAt: Date

    init(
        serverUserId: UUID,
        appleSub: String,
        email: String? = nil,
        displayName: String? = nil,
        sex: BodySex = .male,
        createdAt: Date = .now
    ) {
        self.serverUserId = serverUserId
        self.appleSub = appleSub
        self.email = email
        self.displayName = displayName
        self.sex = sex
        self.createdAt = createdAt
    }
}
