## Why

Apple Sign In 在协议层**不提供性别**，**姓名只在用户首次授权时返回一次且可为空**（中转邮箱 / 隐藏姓名场景），后续静默登录都拿不到。因此要拿到称呼与性别，只能由 App 在首登后自己向用户收集。

更紧迫的是：当前 `UserProfile.sex` 默认 `.male` 且无首登采集——一名女性用户在自己手动去「我的」页改之前，肌群高亮图体型一直渲染成男性。这不是体验瑕疵，是影响约一半潜在用户的事实性错误。同时这三项资料要么不存在、要么只存在本地（`UserProfile.sex` 纯本地不同步），换设备即丢。本变更通过一张**首登资料补全页**一次性受控解决，并把资料升级为后端持久化画像。

## What Changes

- **新增首登资料补全门控**：Apple 登录后，若后端 profile 的称呼为空，强制进入全屏补全页，提交成功才进入主 App。门控以「后端 profile 称呼为空」判定，**不**用 `AuthResponse.newUser`（中途杀 App 会漏人；该字段保留作辅助）。
  - **称呼**：必填；首登用 Apple 回传的全名预填，可改；Apple 隐藏姓名时为空需手填。
  - **性别**：必填，默认「男」（有默认值故不阻塞，但需用户确认）。
- **性别语义合并（BREAKING·语义）**：现有 `UserProfile.sex`（纯本地、仅切肌群图）升级为「用户资料 + 顺带驱动肌群图」单一字段，提升为后端存储并随登录回拉。不另开 `gender` 列。
- **后端**：`app_user` 复用 `display_name`、新增 `sex`（可空）一列，V3 Flyway 迁移；新增 `GET /me`（拉完整画像）与 `PATCH /account/profile`（带幂等键写资料）两个 REST 接口（服务端权威域，**非**同步 LWW 域）。
- **我的页二次修改**：新增「个人资料」分组——称呼行点击进入行内编辑（保存乐观本地写 + PATCH）；性别行从「本地偏好」升级为「资料」并 PATCH 回后端；顶部 ProfileHeader 称呼纯展示、副标由「训练龄」改为「加入于 {月份} · 已记录 {n} 次」。
- **存量用户迁移**：老用户称呼已有值则不挡，从未填过则进来自动走补全页；本地已有的 `sex` 默认值在首次 PATCH 时回填后端。
- **离线**：改资料走乐观本地写 + REST PATCH，失败静默重试，不进 SwiftData 同步信封。
- **删除重装登录态修复（决策 7，方案 A）**：iOS Keychain 跨重装存活而 SwiftData/UserDefaults 被清空，导致「重装后跳过 Apple 登录却又误弹补全页」（失效 token 还会叠加成补全页死锁）。修为「重装 = 干净重来」——重装首启清孤儿 token 回登录页；并补三条地基：全局 401→登出、补全页加「退出登录」逃生口、`refreshProfile` 区分「拉取失败」与「确认无名字」不再误判。

## Capabilities

### New Capabilities
- `user-profile`: 后端持久化的用户画像资源（称呼 / 性别）、`GET /me` 与 `PATCH /account/profile` 契约、首登补全门控的判定与流程。

### Modified Capabilities
- `profile-ui`: 新增「个人资料」分组（称呼行内编辑 + 性别行升级为资料并同步）；ProfileHeader 副标由训练龄改为加入月份 + 已记录次数；登录后新增首登补全页路由。

## Impact

- **后端**：`account` 包新增 profile 读写（新增 `ProfileController` 提供 `GET /me` 与 `PATCH /account/profile`、新增 `ProfileService` 与 `ProfileResponse` DTO）；`AppUser` 实体加 `sex` 字段；新增 `V3__profile_fields.sql` 迁移。
- **iOS**：新增首登补全页视图 `ProfileCompletionView` + `RootView` 门控分支；`UserProfile.sex` 纳入后端回拉/上行；`SessionStore` 登录后拉 `GET /me`、新增 PATCH 上行（乐观本地写 + 失败重试）；`ProfileView` 新增「个人资料」分组（称呼行内编辑 + 性别）、header 副标改写；新增 `ProfileAPI` 与 `ProfileDTO`/`ProfilePatchRequest`。
- **契约**：`AuthResponse.newUser` 不再作为唯一首登信号（保留字段，仅作辅助）。

## Non-goals

- 不做头像上传 / 自定义头像（仍用首字母圆形头像）。
- 不采集训练资历 / 训练年限（已明确不做）。
- 不做生日 / 身高 / 体重等更多画像字段（本次仅称呼 / 性别）。
- 不把 profile 纳入 LWW 同步域（走简单 REST 服务端权威）。
- 不做称呼敏感词过滤 / 多语言校验（仅基础非空与长度上限）。
- 不在 Team 队友资料里展示性别（超出本次「首登 + 我的页编辑」范围）。
- 不引入第三方登录或更换登录方式。
