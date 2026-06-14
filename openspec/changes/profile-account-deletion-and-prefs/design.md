## Context

「我的」页缺两项上架硬卡点(删除账号、隐私/条款可达)与两项可用性缺口(训练偏好无入口、HealthKit 死展示)。其中**删除账号**是唯一跨前后端、且涉及合规与不可逆数据操作的复杂项,本设计主要为它服务,其余三项实现直接、仅在末尾简述。

当前相关现状(已核对代码):

- 后端身份三层 `app_user + user_identity(provider, provider_user_id)`;登录 `AuthController POST /auth/apple` → `AuthService.loginWithApple` 仅校验 `identityToken` 后签发自有无状态 JWT。
- `AppleLoginRequest` record **只有 `identityToken`** 一个字段;iOS `AuthService.swift` 登录只取 `credential.identityToken`,**未取 `authorizationCode`**。
- `user_identity` 实体/表**无 refresh_token 列**;后端无 `.p8` client_secret 签发能力、无调用 Apple token/revoke endpoint 的代码。
- 已存在 `AuthService.handleRevokeNotification`(`POST /auth/apple/revoke`)/ `revokeBySub`,处理 Apple **S2S `account-delete` 反向通知**(Apple → 我方)。本次新增的是**用户主动删号**(App → 我方 → Apple)方向。
- 接口命名规范:资源根 + RESTful 动词(`DELETE /teams/{teamId}`、退团 `DELETE /teams/{teamId}/members/me`、`POST /auth/apple`)。
- 数据库 10 张表,外键多为普通 `REFERENCES app_user(id)`,**仅 `workout` 子树与 `checkin_reaction` 带 `ON DELETE CASCADE`**。
- iOS 端 `RestTimer.defaultDuration`(默认 90s)/`hapticsEnabled`(默认开)已存 UserDefaults;`HealthKitManager.requestAuthorization`、`PushManager` 授权链路均已存在;JWT 存 Keychain。

## Goals / Non-Goals

**Goals:**
- 提供 App 内可达、二次确认、不可逆的账号删除,满足 Apple 5.1.1(v)。
- 后端单事务级联**物理硬删**该 user 全部数据(团主删号解散团队),不留残留、不留半删。
- **真正主动撤销 Apple 授权**(决策 B):补「登录存 `authorization_code` → 换 `refresh_token`」链路,删号时调用 Apple revocation endpoint;`.p8` 凭据缺失时降级不阻断。
- 删号二次确认**显式列出影响面**(将解散 N 个团队、影响 M 名成员)。
- 隐私/条款在 App 内(登录页 + 我的页)可达。
- 训练偏好与 HealthKit 授权补齐为可操作 UI。

**Non-Goals:**
- 单位 kg/lb、改昵称/头像、转移团主、细粒度通知开关、删号冷静期、DB 层 `ON DELETE CASCADE` 重构(见 proposal Non-goals)。
- JWT 服务端黑名单/吊销列表(沿用无状态 JWT,见 D4)。
- refresh_token 列加密存储(MVP 存明文列 + 不入日志,加密留待后续,见 Risks)。

## Decisions

### D1. 删除方式:应用层单事务、按 FK 拓扑顺序硬删

不改现有外键约束,在 `@Transactional` service 内按依赖拓扑**先子后父**逐表 `DELETE`:

```
收集 ownedTeamIds(owner_user_id = me):
  delete checkin_reaction  where checkin_id in (ownedTeams 的 checkins) 或 user_id = me
  delete team_checkin      where team_id in ownedTeamIds 或 user_id = me
  delete team_member       where team_id in ownedTeamIds 或 user_id = me
  delete team              where id in ownedTeamIds
自身数据:
  delete workout (子树 CASCADE) / workout_plan / custom_exercise
  delete device_token / idempotency_key / user_identity
  delete app_user where id = me
```

任一步异常 → 事务整体回滚,接口返回非 2xx。不用 DB CASCADE 是为避免改约束/加迁移、保持删除顺序显式可测。

### D2. 团主删号 = 解散团队

被删 user 作为 owner 的 team 连同其**全部成员**的 member/checkin/reaction 一并删除;作为普通成员加入的他人团队,只删本人记录。两维度分别按 `ownedTeamIds` 与 `user_id = me` 处理。不做转移团主。

### D3. Apple token 主动 revoke(决策 B:真正撤销 + 降级兜底)

**采纳选项 B**——实现真正的主动撤销,而非仅靠 S2S 反向通知。链路:

1. **iOS 登录补回传 `authorizationCode`**:`AuthService.swift` 取 `credential.authorizationCode`,`AppleLoginRequest` 加 `authorizationCode` 字段(可选——仅首次/重新授权时 Apple 才下发)。
2. **后端换 `refresh_token`**:用 `.p8` 私钥签发 Apple **client_secret**(ES256 JWT,`aud=appleid.apple.com`),携 `authorizationCode` 调 `POST https://appleid.apple.com/auth/token` 换取 `refresh_token`,持久化到 `user_identity.apple_refresh_token`(**V2 迁移新增列**)。
3. **删号时撤销**:删号 service 用 `refresh_token` + client_secret 调 `POST https://appleid.apple.com/auth/revoke` 撤销授权,再执行本地级联删除。
4. **降级兜底**:`.p8` 凭据缺失、或该 user 无已存 `refresh_token`(如老用户登录时未回传 code)→ 记 `warn` 日志、跳过 revoke、**仍完整执行本地删除并返回 2xx**。revoke 失败不回滚删除。
5. 与既有 `handleRevokeNotification`/`revokeBySub` 对齐:主动删除后 user 已不存在,Apple 后续 S2S `account-delete` 通知走幂等空操作。

client_secret 签发与 token/revoke HTTP 调用集中在 auth 域新组件(如 `AppleClientSecretFactory` + `AppleTokenClient`),复用既有 nimbus-jose-jwt 依赖。

### D4. JWT 失效策略:沿用无状态,客户端丢弃

不引入服务端 token 黑名单。删号后旧 JWT 在 TTL 内签名仍有效,但其 `user` 已不存在,业务查询查不到;客户端删号成功即清 Keychain JWT 并登出。多设备场景其它设备后续请求得到 user 不存在,等同登出。

### D5. 客户端删号流程与本地清库

`ProfileView` 账号组「删除账号」→ 先拉删号影响面(D8)→ `paperConfirmDialog`(文案列出「将解散 N 个团队、影响 M 名成员」+ 强调永久不可恢复)→ 调 `DELETE /account`(带幂等键)。成功后:清空本地 SwiftData store + 清 Keychain JWT + `SessionStore.logout()` → 回 LoginView。失败保留现场、提示、可重试。进行中加载态、禁重复。

### D6. 删号接口:`DELETE /account` + 幂等

新建 `AccountController @RequestMapping("/account")` + `@DeleteMapping`(无子路径),JWT 鉴权删自身——与现有 `POST /auth/apple`(资源根+动词)、`DELETE /teams/{teamId}` 风格一致;JWT 即身份,无需 `/me` 后缀。遵守全站写接口幂等键铁律。天然幂等:重复删除时 user 已不存在 → 空操作返回 2xx。

### D7. 删号影响面预览:`GET /account/deletion-impact`

`AccountController` 增 `@GetMapping("/deletion-impact")`,返回 `{ ownedTeams: int, affectedMembers: int }`(owner 团队数 + 这些团队中除自己外的成员去重计数),供确认框展示真实影响面。轻量只读,不改任何数据。

### D8. 隐私/条款/HealthKit/训练偏好(直接项)

- 隐私/条款:`SFSafariViewController` 打开后端页面;URL 收敛到单一配置(`AppConfig`),登录页与我的页共用。
- HealthKit:行点击复用 `HealthKitManager.requestAuthorization`,授权后刷新授权态。
- 训练偏好:UI 读写既有 `RestTimer.defaultDuration`/`hapticsEnabled`;通知行读系统授权态 + `openSettingsURLString` 跳转。无新数据模型。

### Day-1 铁律落点

- **身份三层**:`refresh_token` 随 `user_identity`(provider 维度)存储,不污染 `app_user`;删除显式清 `user_identity` 后删 `app_user`,不以 Apple ID 为主键。
- **幂等键**:删号接口带幂等键(D6)。
- **软删 vs 硬删**:同步域日常用 `deletedAt` 墓碑;账号删除是终态合规操作,**例外地物理硬删整行**(无对象需再同步 + 合规要求真正删除)。这是对软删惯例的有意例外。
- **同步字段**:删号经 REST 终态操作,不走同步管道;其它设备通过「user 不存在」感知。

## Risks / Trade-offs

- [`refresh_token` 明文存列,泄露则可被用于撤销/换 token] → MVP 不入日志、限制查询面;后续加列加密(KMS/对称密钥)。
- [老用户登录时未回传 `authorizationCode` → 无 refresh_token,删号时 revoke 走降级] → 接受;下次重新授权时补全;降级仍真正删数据 + S2S 反向通知兜底。
- [Apple token/revoke endpoint 网络失败] → revoke 失败不阻断本地删除(D3.4);记日志便于排查。
- [硬删不可逆,误触即永久丢失] → 二次确认 + 列影响面 + 文案强调 + 与「退出登录」分级。
- [团主删号导致其他成员无预警失去团队] → 确认框显式列「影响 M 名成员」;MVP 接受。
- [新增挂 app_user 的表时漏补删除逻辑] → 删除逻辑集中单一 service + 注释清单 + 测试覆盖各表清零。

## Migration Plan

- **新增数据库迁移 `V2__add_apple_refresh_token.sql`**:`ALTER TABLE user_identity ADD COLUMN apple_refresh_token text`(可空)。Flyway 自动执行。
- 配置:Apple `.p8` 私钥 / Key ID / Team ID / Service ID(client_secret 签发用),隐私/条款 URL 配置项。`.p8` 缺失时 D3 降级,不阻塞发布。
- 部署顺序:后端(V2 迁移 + 登录存 token + 删号接口 + revoke + 影响面接口)→ iOS(登录回传 code + 删号入口与流程)。后端先行兼容旧客户端(authorizationCode 可空)。
- **回滚**:接口可下线、列可保留;但**已执行的删除不可回滚**(数据已物理删除)——设计预期,非缺陷。

## Open Questions

(已全部决议)
1. ✅ Apple revoke → **选 B**:补 `authorization_code → refresh_token` 链路做真正主动撤销 + `.p8` 缺失降级。
2. ✅ 接口命名 → 按现有规范 **`DELETE /account`**(新建 `AccountController`)。
3. ✅ 团主确认框 → **显式列出影响面**(`GET /account/deletion-impact` 返回团队数 + 成员数)。
