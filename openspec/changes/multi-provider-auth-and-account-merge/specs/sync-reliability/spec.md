## ADDED Requirements

### Requirement: 账号合并后同步水位重置

账号合并成功后，客户端 SHALL 重置本地所有同步域水位和待同步身份上下文，并按 target 账号重新执行同步收敛。客户端 MUST NOT 沿用 source 账号或合并前账号的 `since` 水位来拉取 target 数据，避免漏拉已迁移数据。

#### Scenario: 合并成功后重置水位
- **WHEN** 客户端收到账号合并成功响应
- **THEN** 客户端清除所有 `SyncDomain` 水位
- **AND** 触发一次全量 pull/syncAll

#### Scenario: 不沿用 source 水位
- **WHEN** source 账号已合并到 target 账号
- **THEN** 客户端不得使用 source 账号保存的同步水位请求 target 账号增量数据

### Requirement: 账号合并后本地归属收敛

账号合并成功后，客户端 SHALL 以服务端 target 账号返回的数据为准更新本地 SwiftData。若本地仍存在 source 账号 userId 关联的缓存、Team 分享状态或同步队列，客户端 MUST 清理或重建，避免把 source 账号数据再次上传。

#### Scenario: 清理 source 本地缓存
- **WHEN** 合并成功后本地存在 source userId 关联的 Team 分享状态或同步队列
- **THEN** 客户端清理这些 source 关联缓存
- **AND** 后续写入只使用 target userId

#### Scenario: 合并后离线待上传数据
- **WHEN** 合并确认前客户端存在离线待上传数据
- **THEN** 客户端在合并成功后重新标记并按 target 账号上传，或提示用户重新同步
- **AND** 不再使用 source userId 发起 push
