## MODIFIED Requirements

### Requirement: 服务端账号级联硬删

账号删除 SHALL 在单一数据库事务内物理硬删（非软删墓碑）该 user 名下的个人数据，使 Apple 审核和用户隐私删除可验证「数据已真正删除」。删除范围 MUST 覆盖：`user_identity`、手机号身份密文/盲索引、短信 challenge 中与该用户关联的记录、账号合并临时 token、`idempotency_key`、`device_token`、`custom_exercise`、`workout_plan_group`、`workout_plan`、`workout` 及其子树（`workout_exercise` / `workout_set`，随聚合根 CASCADE）、该用户自己的 `team_member`、该用户自己的 `team_checkin`、该用户自己的 `checkin_reaction`、该用户自己的 Team 计划分享与事件、以及最后的 `app_user` 行。事务内任一步失败 MUST 整体回滚，不留半删状态。

账号删除 MUST NOT 默认物理删除其他用户的 `team_member`、`team_checkin` 或 `checkin_reaction`。若被删用户是 Team owner，系统 SHALL 按「团主删号转移 Team owner」处理 Team 归属，而不是把其他成员数据纳入本次账号级联硬删。

#### Scenario: 级联删除全部本人数据
- **WHEN** 用户删除账号
- **THEN** 上述所有表中归属该 user 的个人行被物理删除，`app_user` 行被删除，数据库中查不到该 user 任何个人残留

#### Scenario: 删除手机号身份密文
- **WHEN** 绑定手机号的用户删除账号
- **THEN** 该用户的 phone identity、手机号密文、手机号盲索引和展示尾号被删除

#### Scenario: 不删除其他成员历史
- **WHEN** Team owner 删除账号，且 Team 中存在其他成员
- **THEN** 其他成员的 `team_member`、`team_checkin` 与 `checkin_reaction` 不因本次账号删除而被物理删除

#### Scenario: 事务失败整体回滚
- **WHEN** 级联删除过程中某一步抛错
- **THEN** 整个事务回滚，用户数据保持删除前状态，接口返回错误（非 2xx），不产生半删数据

### Requirement: Apple token 主动撤销(真正撤销 + 降级兜底)

删除自身账号时，后端 SHALL 对该用户已绑定的 Apple identity 尽力主动撤销 Apple 授权：使用已持久化的 Apple `refresh_token` 与 `.p8` 签发的 client_secret，调用 Apple token revocation endpoint。若该用户未绑定 Apple、Apple `.p8` 凭据缺失、或该用户无已存 `refresh_token`，服务端 SHALL 降级：记录 warning 日志并继续完成本地数据删除，MUST NOT 因 revoke 失败而阻断或回滚账号删除主流程。本能力 SHALL 与 Apple S2S 撤销通知对齐，避免重复或冲突的注销逻辑。

#### Scenario: 凭据齐全时真正撤销 Apple 授权
- **WHEN** 用户删号且绑定了 Apple，`.p8` 凭据齐备、该用户已存 `refresh_token`
- **THEN** 后端以 client_secret + refresh_token 调用 Apple revocation endpoint 撤销授权，并完成本地数据删除

#### Scenario: 未绑定 Apple 时跳过 revoke
- **WHEN** 仅绑定微信或手机号的用户删除账号
- **THEN** 后端不调用 Apple revocation endpoint
- **AND** 仍完整执行本地数据删除

#### Scenario: 凭据缺失时降级不阻断
- **WHEN** 用户删号但 Apple `.p8` 凭据缺失或无可撤销 token
- **THEN** 后端记录 warning 日志、跳过 revoke、仍完整执行本地数据删除并返回 2xx

## ADDED Requirements

### Requirement: 删除账号清理多 provider 身份

账号删除 SHALL 清理该用户全部 provider 身份，包括 Apple、微信和手机号。删除过程 MUST 删除微信 openid/unionid 存储、手机号密文、手机号盲索引、验证码未消费 challenge 与合并临时凭据。删除后，这些 provider 身份可被用户重新注册为新账号。

#### Scenario: 删除微信身份后可重新登录建号
- **WHEN** 绑定微信的用户删除账号后，再次使用同一微信登录
- **THEN** 系统不复用已删除账号
- **AND** 可按首次微信登录创建新账号

#### Scenario: 删除手机号身份后可重新注册
- **WHEN** 绑定手机号的用户删除账号后，再次使用同一手机号验证码登录
- **THEN** 系统不复用已删除账号
- **AND** 可按首次手机号登录创建新账号
