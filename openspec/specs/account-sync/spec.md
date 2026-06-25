# account-sync Specification

## Purpose

定义 DontLift 的账号认证、身份模型、离线优先同步、幂等写入和推送通道基线，确保客户端本地真相源与后端账户体系、同步冲突处理和 APNs 事件投递保持一致。

## Requirements

### Requirement: Apple Sign-In 登录

系统 SHALL 仅提供「使用 Apple 登录」作为身份认证方式。客户端获取 Apple identityToken 后提交后端，后端 MUST 通过 Apple 公钥（JWKS，需缓存）验证该 JWT 的签名、issuer、audience 与有效期，并以 token 中的 `sub` 作为该 Apple 身份的唯一标识。

#### Scenario: 首次登录创建账户
- **WHEN** 用户首次用 Apple 登录且后端校验 identityToken 通过
- **THEN** 系统创建 `user` 记录并关联一条 `identity_provider=apple, provider_user_id=<sub>` 的身份记录，签发应用自有 JWT 会话令牌返回客户端

#### Scenario: 老用户再次登录
- **WHEN** 已存在 `provider_user_id` 对应身份的用户再次登录
- **THEN** 系统复用既有 `user`，不创建新账户，签发新的会话令牌

#### Scenario: 私有中继邮箱仅首次可得
- **WHEN** Apple 在首次登录返回用户邮箱（可能为 privaterelay 地址）
- **THEN** 系统 MUST 持久化该邮箱，因为后续登录 Apple 不再返回邮箱

### Requirement: 用户身份三层模型

系统 SHALL 采用 `user`（业务主体）、`identity_provider`、`provider_user_id` 三层结构存储身份。业务数据 MUST 外键关联 `user.id`，MUST NOT 直接以 Apple 的 `sub` 作为业务主键。

#### Scenario: 未来扩展登录方式不需重构
- **WHEN** 后续需要新增手机号或微信等登录方式
- **THEN** 仅需为同一 `user` 增加一条新的身份记录，已有业务数据无需迁移

### Requirement: Apple 授权撤销回调

系统 SHALL 提供一个接收 Apple 服务器通知的回调端点，处理用户撤销 Apple Sign-In 授权的事件（满足 App Store 审核要求）。

#### Scenario: 用户撤销授权
- **WHEN** 系统收到 Apple 发送的账户撤销/删除通知且通过签名校验
- **THEN** 系统注销该用户的所有会话，并删除或匿名化其账户数据

### Requirement: 离线优先的本地存储与同步

系统 SHALL 以客户端本地存储为训练记录、自定义动作和训练计划的编辑真相来源，写操作 MUST 先落本地再异步同步到服务端。所有可同步对象 MUST 携带 `serverId`、`localId`、`updatedAt`、`deletedAt`、`version` 字段，并维护 `syncStatus` 与失败重试队列。

#### Scenario: 离线记录训练
- **WHEN** 用户在无网络环境下保存一条训练记录
- **THEN** 记录立即写入本地并标记为待同步，恢复网络后自动同步到服务端

#### Scenario: 软删除同步
- **WHEN** 用户删除一条已同步的记录
- **THEN** 系统将该记录的 `deletedAt` 置位并同步，服务端按软删除处理而非物理删除

### Requirement: 写接口幂等性

所有产生数据写入的服务端接口 SHALL 接受幂等键（idempotency key），对相同幂等键的重复请求 MUST 返回首次结果而不重复写入。

#### Scenario: 弱网重复提交
- **WHEN** 客户端因超时重试，使用相同幂等键再次提交同一条训练记录
- **THEN** 服务端识别幂等键并返回首次创建的记录，不产生重复数据

### Requirement: 同步冲突处理

当同一对象在本地与服务端均被修改产生冲突时，系统 SHALL 采用 last-write-wins（以 `updatedAt` 较新者为准）策略解决，并 MUST 向用户提示发生了冲突覆盖。系统 MUST NOT 进行复杂的字段级自动合并。

#### Scenario: 双端修改冲突
- **WHEN** 同一记录在两台设备上离线分别被修改后先后同步
- **THEN** 系统保留 `updatedAt` 较新的版本，并提示用户其较旧的修改已被覆盖

### Requirement: APNs 推送通道

系统 SHALL 通过 APNs（基于 token 的 .p8 认证）向客户端推送 Team 相关事件（队友打卡、收到表情回应）。系统 MUST NOT 使用 WebSocket 长连接实现实时性；客户端进入相关页面时通过拉取获取最新状态。

#### Scenario: 队友打卡推送
- **WHEN** 同一 Team 内某成员完成训练并把该训练分享到该 Team
- **THEN** 系统向该 Team 其他成员推送一条 APNs 通知
