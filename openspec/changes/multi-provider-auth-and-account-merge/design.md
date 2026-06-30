## Context

现有账号体系只有 `/auth/apple`，`user_identity.provider` 受数据库约束限制为 `apple`，iOS 登录页也只展示 Apple 登录。仓库早期设计已采用 `app_user + user_identity(provider, provider_user_id)` 身份三层模型，因此新增微信和手机号不需要改变业务数据主键，但需要扩展 provider 约束、客户端登录入口、短信安全和账号合并语义。

本 change 的关键约束：

- 线上存量用户使用 Apple 登录，不能因为新增微信/手机号导致训练、计划、Team 数据丢失。
- 微信是国内首推入口，但 iOS 未安装微信时必须隐藏或降级，避免 App Store 审核问题。
- 手机号仅支持中国大陆 `+86`，需要短信验证码登录、绑定和合并验证。
- 手机号不得明文作为身份主键；同时要保留短信发送能力。
- 一键合并必须证明两个账号都归当前操作者，不能依靠昵称、头像、手机号相似性或 Apple 邮箱猜测。

## Goals / Non-Goals

**Goals:**

- 支持微信、Apple、手机号三种登录方式，并保持 `app_user.id` 作为唯一业务主体。
- 允许任一 provider 首登建号，也允许登录后绑定其它 provider。
- 手机号使用 HMAC 盲索引做查找唯一性，使用加密密文支持短信投递和账号展示。
- 支持当前登录账号与另一已验证账号的一键合并，迁移 source 账号个人数据和登录身份到 target 账号。
- 合并、删号、撤销授权后，旧 JWT 不得继续访问已删除或已合并账号。
- 短信验证码具备成本防护：限流、尝试次数、过期、消费、预算和 kill switch。

**Non-Goals:**

- 不支持非中国大陆手机号、邮箱、密码、游客或第三方 Web 登录。
- 不实现 Android 微信、微信扫码登录、小程序登录或微信支付。
- 不做字段级智能去重，不尝试合并两条“看起来一样”的训练记录。
- 不建设后台人工改绑系统。
- 不在客户端保存微信 `AppSecret`、短信密钥、手机号加密密钥或 HMAC pepper。

## Decisions

### D1. 扩展 `user_identity`，但业务主体仍只有 `app_user`

`user_identity.provider` 扩展为 `apple`、`wechat`、`phone`。`provider_user_id` 的取值规则：

- Apple：Apple `sub`。
- WeChat：优先使用 `unionid`；若微信接口未返回 `unionid`，登录失败并提示稍后重试，不使用昵称或头像兜底。
- Phone：`phone:` + `HMAC-SHA256(phone_lookup_pepper, normalized_e164_phone)`。

`user_identity` 继续保持 `(provider, provider_user_id)` 唯一。新增同一 `user_id + provider` 的活跃唯一约束，避免一个账号绑定多个手机号或多个微信身份。若合并时 source 与 target 在同一 provider 上存在不同活跃身份，合并阻断，要求用户先解除冲突身份。

备选：手机号明文作为 `provider_user_id`。否决原因是手机号会散落在唯一索引、错误信息、审计和潜在日志中，泄漏面太大。

### D2. 手机号采用 HMAC 盲索引 + 可逆加密密文

新增手机号身份详情表，和 `user_identity` 一对一：

```sql
CREATE TABLE user_phone_identity (
    user_identity_id uuid PRIMARY KEY REFERENCES user_identity(id) ON DELETE CASCADE,
    phone_lookup_hash text NOT NULL UNIQUE,
    phone_ciphertext bytea NOT NULL,
    phone_last4 text NOT NULL,
    phone_country_code text NOT NULL DEFAULT '86',
    phone_key_version int NOT NULL,
    verified_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL
);
```

- 查找、唯一约束、登录匹配、限流使用 `phone_lookup_hash`。
- 短信投递使用用户本次输入手机号；账号页展示使用 `phone_last4` 和脱敏格式。
- 只有需要重发、审计或后续短信通知时才解密 `phone_ciphertext`。
- `phone_ciphertext` 使用 AES-GCM 或 KMS envelope encryption，密钥版本写入 `phone_key_version`，便于轮换。
- 完整手机号不得进入业务日志、异常日志、Sentry 或 ProblemDetail。

备选：只存 HMAC，不存密文。优点是最小化 PII；缺点是后续无法对已绑定手机号主动发送短信，也无法在用户未重新输入手机号时恢复投递地址。当前需求需要短信发送能力，因此保留加密密文。

### D3. 微信登录由客户端拿 code，后端换 token 和身份

iOS 集成 WeChat Open SDK：

- `WXApi.registerApp(appId, universalLink:)` 注册。
- `SendAuthReq.scope = "snsapi_userinfo"`，`state` 使用随机值防 CSRF。
- 客户端收到微信回调 `code` 后提交后端。
- 后端使用 `AppID/AppSecret/code` 调微信 `/sns/oauth2/access_token`，读取 `openid/unionid`。
- `AppSecret` 只在后端环境变量中保存。

未安装微信时，iOS 登录页不展示微信主按钮，改用 Apple 和手机号入口。

### D4. 登录、绑定、合并使用同一套身份证明模型

匿名登录：

```text
provider credential -> 解析 provider subject
  ├─ identity 存在：签发该 user JWT
  └─ identity 不存在：创建 app_user + identity，签发 JWT
```

已登录绑定：

```text
当前 JWT target user + 新 provider credential
  ├─ identity 不存在：绑定到 target user
  ├─ identity 已属 target：幂等成功
  └─ identity 属于 source user：返回 merge preview + mergeToken
```

合并确认：

```text
POST /account/merge
Authorization: target JWT
Idempotency-Key: ...
body: mergeToken
```

`mergeToken` 为短 TTL 服务端签名令牌或数据库 challenge，必须绑定 `targetUserId`、`sourceUserId`、验证 provider、验证时间和过期时间。确认合并时重新校验 target JWT、mergeToken 未过期且 source 未变化。

### D5. 账号合并采用 target 保留、source 迁移后删除

合并在单一事务内执行。target 是当前登录账号，source 是刚通过另一身份验证证明归属的账号。

迁移策略：

- `app_user`：target 的 `display_name/sex/first_login_email` 优先；source 仅填补 target 空字段。
- `user_identity`：source 身份迁移到 target；若同 provider 不同身份冲突则阻断。
- `user_phone_identity`：随 source phone identity 迁移。
- `device_token`：迁移到 target；APNs token 唯一冲突时保留 target，删除 source duplicate。
- `idempotency_key`：可迁移无冲突记录；冲突记录删除，不影响业务数据。
- 同步域：`custom_exercise`、`workout_plan_group`、`workout_plan`、`workout`、`workout_exercise` 的 `user_id` 改为 target；子表随根保持不变。
- Team 域：source 自己的 `team_member`、`team_checkin`、`checkin_reaction`、`team_plan_share`、`team_plan_share_event` 归属迁移到 target；唯一冲突时保留 target 已有关系并迁移非冲突数据。
- source 拥有的 Team owner 转为 target；若 target 已在同 Team 内，最终只保留一条 target 成员关系，并确保 target 是 owner。
- 合并完成后写 `account_merge` 审计记录，物理删除 source `app_user` 或标记为不可登录；安全过滤器必须拒绝 source 旧 JWT。

备选：保留 source 并在读取时重定向到 target。否决原因是所有业务查询都要处理别名，复杂度会扩散到同步、Team 和统计路径。

### D6. JWT 校验必须查账号活跃状态

现有 JWT 是 stateless，`sub = userId`。多身份和合并后，仅验证签名不够。`JwtAuthFilter` 或等价认证层必须确认：

- `app_user` 存在；
- 未被硬删或软删；
- 未被标记为 merged/source retired；
- token `iat` 不早于账号的 `tokens_invalid_before`（如果采用该字段）。

这同时修复删号、合并和 Apple 撤销后的旧 token 访问风险。

### D7. 短信验证码使用专用 challenge，不复用当前幂等表

匿名短信发送没有 `userId`，不能复用现有 `idempotency_key(user_id, idem_key)`。新增 `sms_challenge`：

```sql
CREATE TABLE sms_challenge (
    id uuid PRIMARY KEY,
    purpose text NOT NULL CHECK (purpose IN ('login', 'link', 'merge')),
    phone_lookup_hash text NOT NULL,
    phone_ciphertext bytea,
    code_hash text NOT NULL,
    expires_at timestamptz NOT NULL,
    consumed_at timestamptz,
    attempt_count int NOT NULL DEFAULT 0,
    request_ip_hash text,
    device_id_hash text,
    created_user_id uuid,
    created_at timestamptz NOT NULL
);
```

限流维度至少包含手机号、IP、设备、账号、手机号+IP。冷却期内重复请求不重复发短信，返回同一 challenge 的剩余冷却信息。验证码只存 hash，成功后立即 `consumed_at`。

### D8. iOS 本地用户模型去 Apple 化

`UserProfile.appleSub` 不再作为通用登录身份字段。客户端应把登录身份列表视为服务端权威，通过账号安全接口拉取脱敏身份摘要。SwiftData 本地只保留当前 `serverUserId`、画像、展示所需的脱敏信息；JWT 仍只存 Keychain。

## Risks / Trade-offs

- [账号合并误操作不可逆] → 合并必须要求当前 JWT + source provider credential 双重证明，并显示 source/target 摘要后强确认。
- [合并事务涉及表多，唯一约束复杂] → 先实现确定性迁移和阻断策略，不做模糊去重；对每张挂 `app_user` 的表加测试。
- [source 旧 JWT 继续访问] → JWT 认证层查账号活跃状态；合并后 source 硬删或标记 retired。
- [手机号密文增加密钥管理复杂度] → 使用 key version，密钥只在服务端配置/KMS；日志和响应只暴露脱敏手机号。
- [短信被刷导致成本失控] → 多维限流、验证码冷却、供应商预算、kill switch、可选 App Attest / DeviceCheck。
- [微信审核或配置未就绪阻塞上线] → 后端和 iOS 使用 feature flag；微信不可用时保留 Apple/手机号登录。
- [Apple 撤销和多身份语义冲突] → 撤销 Apple 时只解绑 Apple；最后一个身份才进入注销兜底。

## Migration Plan

1. 后端先发非破坏性迁移：放宽 `user_identity.provider` 约束，新增手机号、短信、合并、会话失效相关表和索引。
2. 部署后端新接口，但默认关闭微信和手机号入口；Apple 登录保持兼容。
3. 接入短信供应商和密钥配置，在开发/测试环境使用 mock provider 覆盖限流与验证码流程。
4. iOS 接入微信 SDK、手机号验证码页和账号安全页，通过 feature flag 灰度展示。
5. 开启手机号登录，再开启微信登录；上线前完成微信开放平台移动应用审核、Universal Links 验证和短信模板审核。
6. 监控登录成功率、短信发送量、验证码失败率、合并失败率和 401 登出率。

回滚策略：关闭微信/手机号 feature flag 后，Apple 登录继续可用；数据库新增表可保留。若合并能力出问题，关闭合并确认接口，仅保留新 provider 登录和未冲突绑定。

## Open Questions

- 短信供应商选型：阿里云、腾讯云、火山引擎或其它；模板审核和签名由用户侧提供。
- 手机号加密采用云 KMS 还是应用环境密钥；若部署在 Fly.io/国内云，需要确定密钥注入方式。
- 微信开放平台审核完成前，TestFlight 是否隐藏微信入口，还是显示“即将支持”。
- 合并时同 provider 不同身份冲突是否永远阻断，还是后续提供先解绑再合并的引导。
