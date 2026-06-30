## MODIFIED Requirements

### Requirement: Apple Sign-In 登录

系统 SHALL 继续提供「使用 Apple 登录」作为身份认证方式之一。客户端获取 Apple identityToken 后提交后端，后端 MUST 通过 Apple 公钥（JWKS，需缓存）验证该 JWT 的签名、issuer、audience 与有效期，并以 token 中的 `sub` 作为该 Apple 身份的唯一标识。Apple 登录不再是唯一登录方式；同一 `app_user` 可同时绑定 Apple、微信和手机号身份。

#### Scenario: 首次 Apple 登录创建账户
- **WHEN** 用户首次用 Apple 登录且后端校验 identityToken 通过
- **THEN** 系统创建 `app_user` 记录并关联一条 `identity_provider=apple, provider_user_id=<sub>` 的身份记录，签发应用自有 JWT 会话令牌返回客户端

#### Scenario: Apple 老用户再次登录
- **WHEN** 已存在 `provider=apple, provider_user_id=<sub>` 对应身份的用户再次登录
- **THEN** 系统复用既有 `app_user`，不创建新账户，签发新的会话令牌

#### Scenario: 私有中继邮箱仅首次可得
- **WHEN** Apple 在首次登录返回用户邮箱（可能为 privaterelay 地址）
- **THEN** 系统 MUST 持久化该邮箱，因为后续登录 Apple 不再返回邮箱

### Requirement: 用户身份三层模型

系统 SHALL 采用 `app_user`（业务主体）、`identity_provider`、`provider_user_id` 三层结构存储身份。业务数据 MUST 外键关联 `app_user.id`，MUST NOT 直接以 Apple `sub`、微信 `unionid/openid` 或手机号作为业务主键。`user_identity.provider` SHALL 支持 `apple`、`wechat`、`phone`，同一 provider subject 在全站唯一，同一用户同一 provider 最多保留一个活跃身份。

#### Scenario: 扩展登录方式不需迁移业务数据
- **WHEN** 用户在同一账号上新增手机号或微信登录方式
- **THEN** 系统仅为同一 `app_user` 增加新的身份记录，已有训练、计划、Team 和同步数据无需迁移

#### Scenario: 禁止直接使用外部身份作业务主键
- **WHEN** 创建训练、计划、Team 或同步实体
- **THEN** 业务表只引用 `app_user.id`
- **AND** 不引用 Apple `sub`、微信 `unionid/openid` 或手机号

#### Scenario: 同一用户同 provider 冲突
- **WHEN** 已绑定手机号的用户尝试再绑定另一个手机号
- **THEN** 服务端拒绝绑定或要求先解绑旧手机号

### Requirement: Apple 授权撤销回调

系统 SHALL 提供接收 Apple 服务器通知的回调端点，处理用户撤销 Apple Sign-In 授权的事件（满足 App Store 审核要求）。在多身份账号中，Apple 撤销 SHALL 优先解绑 Apple 身份并清除 Apple refresh token；若该账号已无其它可登录身份，系统 MUST 进入注销、删除或不可登录兜底流程，避免留下无法登录但仍活跃的账号。

#### Scenario: 多身份用户撤销 Apple 授权
- **WHEN** 系统收到 Apple 撤销通知且该用户仍绑定微信或手机号
- **THEN** 系统删除或停用该用户的 Apple identity
- **AND** 保留 `app_user`、训练、计划、Team 数据和其它登录身份

#### Scenario: 最后一个身份为 Apple 时撤销
- **WHEN** 系统收到 Apple 撤销通知且该账号没有其它可登录身份
- **THEN** 系统注销、删除或标记该账号不可登录
- **AND** 旧 JWT 不得继续访问该账号数据

## ADDED Requirements

### Requirement: 微信登录

系统 SHALL 支持 iOS 原生 WeChat Open SDK 登录。客户端 MUST 仅提交微信授权临时 `code` 和 `state` 校验结果，后端 MUST 使用服务端保存的 `AppID/AppSecret` 调微信接口换取 `openid/unionid`。系统 MUST 以 `unionid` 作为微信身份唯一标识；未取得 `unionid` 时 MUST 拒绝本次微信登录。

#### Scenario: 首次微信登录创建账户
- **WHEN** 用户首次用微信登录且后端成功换取 `unionid`
- **THEN** 系统创建 `app_user` 和 `provider=wechat, provider_user_id=<unionid>` 身份，签发 JWT

#### Scenario: 微信老用户再次登录
- **WHEN** 已存在 `provider=wechat, provider_user_id=<unionid>` 身份
- **THEN** 系统复用对应 `app_user` 并签发 JWT

#### Scenario: 微信未返回 unionid
- **WHEN** 微信接口未返回 `unionid`
- **THEN** 服务端拒绝登录
- **AND** 不使用昵称、头像或 openid 猜测用户身份

### Requirement: 手机号登录

系统 SHALL 支持中国大陆手机号短信验证码登录。手机号登录 MUST 依赖 `sms-verification` 能力完成验证码发送与校验。验证码通过后，系统使用手机号 HMAC 盲索引查找 `provider=phone` 身份；不存在时创建新 `app_user` 与 phone identity。

#### Scenario: 手机号首次登录创建账户
- **WHEN** 未登录用户提交合法手机号验证码且该手机号尚未绑定任何账号
- **THEN** 系统创建 `app_user` 和 phone identity，签发 JWT

#### Scenario: 手机号老用户登录
- **WHEN** 未登录用户提交合法手机号验证码且该手机号已绑定账号
- **THEN** 系统复用对应 `app_user` 并签发 JWT

#### Scenario: 验证码失败不登录
- **WHEN** 用户提交错误、过期或已消费验证码
- **THEN** 系统拒绝登录
- **AND** 不创建账号或身份

### Requirement: 已登录身份绑定

系统 SHALL 允许已登录用户绑定 Apple、微信或手机号身份。绑定时 MUST 校验 provider 凭证真实有效。若身份未被占用，系统将该身份绑定到当前 `app_user`；若身份已属于当前用户，系统按幂等成功处理；若身份属于其它用户，系统进入 `account-merge` 合并预览流程。

#### Scenario: 绑定未占用身份
- **WHEN** 已登录用户绑定一个未被任何账号占用的微信、Apple 或手机号身份
- **THEN** 系统为当前 `app_user` 创建对应 `user_identity`

#### Scenario: 重复绑定当前身份
- **WHEN** 用户重复绑定已经属于当前账号的身份
- **THEN** 系统返回成功
- **AND** 不创建重复身份记录

#### Scenario: 绑定身份属于其它账号
- **WHEN** 用户绑定的身份已属于其它 `app_user`
- **THEN** 系统不直接改绑
- **AND** 返回账号合并预览和 mergeToken

### Requirement: JWT 主体活跃性校验

系统 SHALL 在 JWT 签名和过期时间校验通过后，继续校验 JWT `sub` 对应的 `app_user` 是否存在且可登录。已删除、已合并、已注销或早于账号失效时间签发的 token MUST 被拒绝。

#### Scenario: 删除账号后旧 token 失效
- **WHEN** 用户账号已被删除后，客户端继续使用旧 JWT 请求鉴权接口
- **THEN** 服务端返回 401

#### Scenario: 合并账号后 source token 失效
- **WHEN** source 账号已合并到 target 账号后，旧设备继续使用 source JWT
- **THEN** 服务端返回 401
- **AND** 不自动返回 target 账号数据
