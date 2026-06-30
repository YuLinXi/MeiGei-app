## ADDED Requirements

### Requirement: 一键账号合并前置验证

系统 SHALL 允许已登录用户通过验证另一个 provider 身份来发起账号合并。合并前 MUST 同时证明 target 账号归属（当前有效 JWT）与 source 账号归属（Apple identityToken、WeChat code 或手机号验证码）。若新验证身份已属于另一个 `app_user`，系统 MUST 返回合并预览和短期有效 mergeToken，而不是直接迁移数据。

#### Scenario: 验证身份属于其它账号
- **WHEN** 已登录用户绑定微信、Apple 或手机号时，该身份已属于另一个账号
- **THEN** 服务端返回合并预览和 mergeToken
- **AND** 不立即迁移任何数据

#### Scenario: 验证身份属于当前账号
- **WHEN** 已登录用户绑定的身份已经属于当前账号
- **THEN** 服务端按幂等成功处理
- **AND** 不返回合并预览

#### Scenario: mergeToken 过期
- **WHEN** 用户使用过期 mergeToken 提交合并确认
- **THEN** 服务端拒绝合并
- **AND** source 与 target 账号数据保持不变

### Requirement: 账号合并事务迁移

系统 SHALL 在单一数据库事务内将 source 账号的个人数据、登录身份、设备 token、Team 关系和同步域数据迁移到 target 账号。事务内任一步失败 MUST 整体回滚。合并完成后 source 账号 MUST 不再可登录。

#### Scenario: 合并迁移个人训练数据
- **WHEN** 用户确认合并且 source 账号拥有训练、计划、计划分组和自定义动作
- **THEN** 这些数据的归属迁移到 target 账号
- **AND** 训练子树仍保持完整

#### Scenario: 合并迁移 Team 数据
- **WHEN** source 账号拥有 Team 成员关系、打卡、表情或计划分享事件
- **THEN** 服务端将这些数据迁移到 target 账号
- **AND** 不删除其它成员的数据

#### Scenario: 合并失败回滚
- **WHEN** 合并事务中任一表迁移失败
- **THEN** 整个合并回滚
- **AND** source 与 target 账号保持合并前状态

### Requirement: 合并冲突处理

系统 SHALL 在合并前检测 source 与 target 的 provider 身份冲突。若两账号存在同一 provider 的不同活跃身份，系统 MUST 阻断合并并返回可解释错误，除非该 provider 身份已经属于 target。唯一约束冲突的数据迁移 MUST 采用确定性策略：保留 target 已有关系，迁移非冲突数据，删除或跳过仅作为缓存的 source 冲突记录。

#### Scenario: 同 provider 不同身份冲突
- **WHEN** source 和 target 都绑定了不同的手机号、微信或 Apple 身份
- **THEN** 服务端拒绝合并
- **AND** 提示用户先解绑冲突身份

#### Scenario: 设备 token 冲突
- **WHEN** source 和 target 拥有相同 APNs device token
- **THEN** 服务端保留 target device token
- **AND** 删除 source duplicate

#### Scenario: 幂等键冲突
- **WHEN** source 和 target 存在相同 idem_key
- **THEN** 服务端可删除 source 冲突幂等缓存
- **AND** 不影响已持久化业务数据

### Requirement: 合并后会话失效与审计

系统 SHALL 在合并完成后使 source 账号旧 JWT 失效，并记录合并审计信息。后续任何携带 source userId 的旧 token 请求 MUST 被拒绝。target 用户继续使用当前会话或收到新的 JWT。

#### Scenario: source 旧 JWT 被拒
- **WHEN** source 账号合并完成后，旧设备继续使用 source JWT 请求任一鉴权接口
- **THEN** 服务端返回 401
- **AND** 不返回 target 账号数据

#### Scenario: 写入合并审计
- **WHEN** 合并成功
- **THEN** 服务端记录 sourceUserId、targetUserId、触发 provider、合并时间和请求 trace
