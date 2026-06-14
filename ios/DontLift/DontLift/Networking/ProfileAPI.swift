import Foundation

/// 用户画像接口（服务端权威域）。对应后端 `GET /me` 与 `PATCH /account/profile`。
enum ProfileAPI {

    /// 拉当前用户完整画像（登录回灌 + 首登门控判定）。
    static func me() async throws -> ProfileDTO {
        try await APIClient.shared.send("GET", "/me")
    }

    /// 部分更新画像（带幂等键）。PATCH 语义：仅 patch 中出现的字段被更新。
    @discardableResult
    static func update(_ patch: ProfilePatchRequest) async throws -> ProfileDTO {
        try await APIClient.shared.send(
            "PATCH", "/account/profile",
            body: patch,
            idempotencyKey: UUID().uuidString)
    }
}
