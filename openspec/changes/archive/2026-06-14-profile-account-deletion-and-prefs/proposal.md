## Why

「我的」(Profile)页目前内容稀薄,且缺两项 **App Store 上架硬卡点**:

1. **没有「删除账号」入口**——App「别练了」用 Apple Sign-In 创建账号,但全端(前端 Profile 仅「退出登录」,后端无删号路由)都没有删除账号的能力。Apple 审核指南 **5.1.1(v)** 强制要求:凡支持账号创建的 App 必须提供 **App 内可达的账号删除路径**(自 2022-06-30 起为必拒项)。不补 = 100% 卡审核。
2. **隐私政策 / 服务条款是死链**——`LoginView` 两个按钮仍是占位、Profile 页无入口,而后端隐私页其实已上线(`dontlift.peipadada.com`)。审核要求两份文档在 App 内可达。

同时顺势补齐两处可用性缺口:**训练偏好**无设置落点(`RestTimer` 的休息时长/震动偏好早已存于 UserDefaults 却无 UI 暴露)、**HealthKit 行是「未授权」死展示**(点不动、无法发起授权)。

## What Changes

- **新增「删除账号」端到端能力**:Profile 新增「账号」分组,内含「退出登录」+「删除账号」(danger 红字 + 二次确认);后端新增删号 REST 接口,**物理硬删 + 事务级联**清除该 user 名下所有数据,团主删号时**直接解散其团队**;后端补**登录持久化 Apple `refresh_token`(由 `authorizationCode` 换取)+ 删号时主动调用 Apple revocation endpoint 真正撤销**(降级容错:无 `.p8`/无 token 时记日志、不阻断删除主流程);客户端删号成功后清本地 SwiftData 并登出回 LoginView。**BREAKING**:删号不可逆,用户数据不可恢复。
- **接通隐私政策 / 服务条款链接**:Profile「关于」组新增两个入口(`SFSafariViewController` 打开后端已上线页面);修 `LoginView` 两个占位按钮指向同一页面。
- **新增「训练偏好」分组**:把 `RestTimer` 已有的「默认休息时长」「震动开关」暴露成设置 UI;「通知」项展示系统授权态并提供跳转系统设置入口。
- **HealthKit 行改为可授权**:把当前「未授权」死展示行改成可点击发起 HealthKit 授权请求的活行;授权态实时反映。

## Capabilities

### New Capabilities
- `account-deletion`: 账号删除端到端能力——客户端发起删号请求与本地数据清除/登出流程,后端账号级联硬删语义(含团主解散、幂等、Apple token 主动 revoke 及降级容错),与既有 Apple S2S `account-delete` 反向撤销通知处理对齐。

### Modified Capabilities
- `profile-ui`: 个人中心设置分组行为扩展——新增「账号」分组(退出登录 + 删除账号入口及二次确认)、新增「训练偏好」分组(默认休息时长 / 震动 / 通知)、「关于」组新增隐私政策与服务条款入口、HealthKit 行由纯展示改为可发起授权;`LoginView` 占位法律链接接通真实页面。

## Impact

- **iOS**:`Profile/ProfileView.swift`(新增两组、改 HealthKit 行)、`Auth/LoginView.swift`(接通占位按钮)、新增账号删除调用与本地清库逻辑(`Sync`/`Persistence` 层 + `SessionStore`)、`Workout/RestTimer.swift` 偏好读写复用、可能新增 `SFSafariViewController` 包装与「训练偏好」子视图;`Auth/AuthService.swift` 登录回传 `authorizationCode`;删号确认前拉 `deletion-impact` 展示影响面。
- **后端**:`auth`/`account` 域新增删号接口(`AuthController`/新建 `AccountController` + service);**事务级联硬删** `app_user` 名下全部表(`user_identity` / `idempotency_key` / `device_token` / `custom_exercise` / `workout_plan` / `workout`→子树 / `team`(团主解散)/ `team_member` / `team_checkin` / `checkin_reaction`);复用/对齐 `AuthService.revokeBySub`;新增 client_secret 签发 + Apple token/revoke 调用(`.p8` 配置,缺失降级);登录补 `authorizationCode`→`refresh_token` 持久化;新增只读 `GET /account/deletion-impact`(团队/成员影响面)。写接口遵守幂等键铁律。
- **依赖 / 配置**:Apple `.p8` 私钥 / Key ID / Team ID / Service ID(client_secret 签发 + token/revoke,属软阻塞,缺失走降级);隐私政策与服务条款页 URL 配置项。
- **数据库**:删除走应用层事务级联;**新增 `V2__add_apple_refresh_token.sql`**(`user_identity` 加 `apple_refresh_token` 列,供删号 revoke)。不改现有外键约束。

## Non-goals

- **单位 kg/lb 切换**:成本在全链路渗透(所有重量展示/输入/图表/PR),本次不做,另行立项。
- **修改头像 / 编辑昵称**:身份信息编辑本次不做。
- **转移团主**:团主删号一律解散团队,不提供「转移所有权后保留团队」选项(后续可加)。
- **细粒度通知开关**:不做 App 内分类通知开关(休息提醒 / Team 动态分别开关),仅展示系统授权态 + 跳系统设置。
- **DB 层 `ON DELETE CASCADE` 重构**:不改现有外键约束,删除走应用层事务。
- **删号冷静期 / 可恢复窗口**:删号即时生效、不可恢复,不做 N 天软删宽限期。
