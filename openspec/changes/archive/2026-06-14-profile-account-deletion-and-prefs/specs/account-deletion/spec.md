## ADDED Requirements

### Requirement: 账号删除接口鉴权与范围

后端 SHALL 暴露一个需 JWT 鉴权的账号删除接口(如 `DELETE /account`),仅允许已登录用户**删除其自身账号**。接口 SHALL 携带幂等键(遵守全站写接口幂等铁律),并在删除完成后返回 2xx 且使当前 JWT 失效(客户端登出)。未携带有效 JWT 的请求 MUST 被拒(401)。

#### Scenario: 已登录用户删除自身账号
- **WHEN** 已登录用户携带有效 JWT 与幂等键调用 `DELETE /account`
- **THEN** 服务端删除该 JWT 所属 user 的账号并返回 2xx,响应不泄露其它用户数据。

#### Scenario: 未鉴权请求被拒
- **WHEN** 请求未携带有效 JWT 调用删除接口
- **THEN** 返回 401,不执行任何删除。

### Requirement: 服务端账号级联硬删

账号删除 SHALL 在单一数据库事务内**物理硬删**(非软删墓碑)该 user 名下的全部数据,使 Apple 审核可验证「数据已真正删除」。删除范围 MUST 覆盖:`user_identity`、`idempotency_key`、`device_token`、`custom_exercise`、`workout_plan`、`workout` 及其子树(`workout_exercise` / `workout_set`,随聚合根 CASCADE)、`team_member`、`team_checkin`、`checkin_reaction`,以及最后的 `app_user` 行。事务内任一步失败 MUST 整体回滚,不留半删状态。

#### Scenario: 级联删除全部用户数据
- **WHEN** 用户删除账号
- **THEN** 上述所有表中归属该 user 的行被物理删除,`app_user` 行被删除,数据库中查不到该 user 任何残留(幂等键、设备 token、训练/计划/自定义动作、Team 成员关系与打卡、表情回应)。

#### Scenario: 事务失败整体回滚
- **WHEN** 级联删除过程中某一步抛错
- **THEN** 整个事务回滚,用户数据保持删除前状态,接口返回错误(非 2xx),不产生半删数据。

### Requirement: 团主删号解散其团队

当被删账号是某 `team` 的 owner 时,删除 SHALL **直接解散该团队**:级联硬删该 team 及其全部 `team_member` / `team_checkin` / `checkin_reaction`。本次 MUST NOT 提供「转移团主」路径(见 proposal Non-goals)。当被删账号仅是普通成员时,SHALL 仅移除其 `team_member` 行及该用户产生的打卡/表情,团队本身与其他成员数据保留。

#### Scenario: 团主删号解散团队
- **WHEN** 一名 team owner 删除账号
- **THEN** 其拥有的 team 及该 team 下全部成员关系、打卡、表情被删除,团队不再存在。

#### Scenario: 成员删号不影响团队
- **WHEN** 一名普通成员删除账号
- **THEN** 其 `team_member` 行与本人打卡/表情被删除,团队及其他成员数据不受影响。

### Requirement: Apple token 主动撤销(真正撤销 + 降级兜底)

删除自身账号时,后端 SHALL 使用该用户已持久化的 Apple `refresh_token`(见「登录持久化 Apple 授权凭据」)与 `.p8` 签发的 client_secret,调用 Apple 的 token revocation endpoint(`POST https://appleid.apple.com/auth/revoke`)**真正撤销**该用户的 Apple 授权(满足 5.1.1(v) 配套要求)。当 Apple `.p8` 凭据缺失、或该用户无已存 `refresh_token` 时,服务端 SHALL **降级**:记录 warning 日志并**继续完成本地数据删除**,MUST NOT 因 revoke 失败而阻断或回滚账号删除主流程。本能力 SHALL 与既有 `AuthService.handleRevokeNotification` / `revokeBySub`(处理 Apple S2S `account-delete` 反向撤销通知)对齐,避免重复或冲突的注销逻辑。

#### Scenario: 凭据齐全时真正撤销 Apple 授权
- **WHEN** 用户删号且 `.p8` 凭据齐备、该用户已存 `refresh_token`
- **THEN** 后端以 client_secret + refresh_token 调用 Apple revocation endpoint 撤销授权,并完成本地数据删除。

#### Scenario: 凭据缺失时降级不阻断
- **WHEN** 用户删号但 Apple `.p8` 凭据缺失或无可撤销 token
- **THEN** 后端记录 warning 日志、跳过 revoke、仍完整执行本地数据删除并返回 2xx。

#### Scenario: 与反向撤销通知对齐
- **WHEN** Apple 之后就同一 user 发来 S2S `account-delete` 通知,而该账号已被主动删除
- **THEN** `revokeBySub` 处理为幂等空操作,不报错、不产生异常副作用。

### Requirement: 客户端删号流程与本地数据清理

客户端 SHALL 在用户于「我的」页确认删除账号后调用删除接口;**成功**后 SHALL 清除本地 SwiftData 全部用户数据与 Keychain 中的 JWT,并将 App 跳回 `LoginView`。删除请求进行中 SHALL 给出加载态并禁止重复触发。删除**失败**时 SHALL 保留本地数据与登录态,并提示错误,允许重试。

#### Scenario: 删除成功清本地并登出
- **WHEN** 客户端收到删除接口 2xx
- **THEN** 本地 SwiftData 用户数据与 Keychain JWT 被清除,App 回到 LoginView。

#### Scenario: 删除失败保留现场
- **WHEN** 删除接口返回错误或网络失败
- **THEN** 本地数据与登录态保持不变,呈现错误提示,用户可重试。

#### Scenario: 进行中防重复提交
- **WHEN** 删除请求正在进行
- **THEN** 入口呈加载态并禁用,重复点击不发起第二次请求。

### Requirement: 登录持久化 Apple 授权凭据

客户端 Apple 登录时 SHALL 回传 `authorizationCode`(`AppleLoginRequest` 新增可选字段)。后端在登录时若收到 `authorizationCode` 且 `.p8` 凭据可用,SHALL 用 client_secret 向 Apple `POST /auth/token` 换取 `refresh_token` 并持久化到 `user_identity.apple_refresh_token`(V2 迁移新增列),供后续删号 revoke 使用。`authorizationCode` 缺失(老客户端/静默登录)或 `.p8` 缺失时,SHALL 跳过且 MUST NOT 阻断登录。`refresh_token` MUST NOT 写入日志。

#### Scenario: 首次登录持久化 refresh_token
- **WHEN** 客户端登录回传有效 `authorizationCode` 且 `.p8` 凭据可用
- **THEN** 后端换取 `refresh_token` 并存入 `user_identity.apple_refresh_token`,登录正常返回 JWT。

#### Scenario: 无 code 或无凭据时登录不受影响
- **WHEN** 登录未带 `authorizationCode`,或服务端无 `.p8` 凭据
- **THEN** 跳过 `refresh_token` 获取,登录仍正常签发 JWT。

### Requirement: 删号影响面预览

后端 SHALL 提供只读接口 `GET /account/deletion-impact`,返回当前用户删号将造成的影响面:`ownedTeams`(其作为 owner、删号时将被解散的团队数)与 `affectedMembers`(这些团队中除本人外的去重成员数)。客户端 SHALL 在删号二次确认框中展示该影响面。该接口 MUST NOT 修改任何数据。

#### Scenario: 返回团队与成员影响数
- **WHEN** 已登录用户请求 `GET /account/deletion-impact`
- **THEN** 返回其 owner 团队数与受影响成员数,数据不被修改。

#### Scenario: 无团队时影响为零
- **WHEN** 用户未拥有任何团队
- **THEN** 返回 `ownedTeams=0`、`affectedMembers=0`。
