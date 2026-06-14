import Foundation

/// 账号自助接口（删号 + 影响面预览）。对应后端 `/account`。
enum AccountAPI {

    /// 删号影响面：将解散的团队数与受影响成员数（只读）。
    static func deletionImpact() async throws -> DeletionImpactDTO {
        try await APIClient.shared.send("GET", "/account/deletion-impact")
    }

    /// 删除自身账号（物理硬删全部数据）。带幂等键；天然幂等（重复删为空操作）。
    static func deleteAccount() async throws {
        try await APIClient.shared.sendVoid(
            "DELETE", "/account",
            idempotencyKey: UUID().uuidString)
    }
}
