## 1. 后端 · 数据模型与迁移

- [x] 1.1 新增 Flyway 迁移 `V3__profile_fields.sql`（V2 已被 apple_refresh_token 占用）：给 `app_user` 加 `sex text CHECK (sex IN ('male','female'))`（**可空、无默认**，null=未设置以避免回灌覆盖本地选择）与 `training_start_year int`（可空，CHECK `year >= 1900`；上界由应用层校验）。
- [x] 1.2 更新 `AppUser` 实体 / `AppUserMapper`，纳入 `sex`、`trainingStartYear` 字段。

## 2. 后端 · Profile REST 接口

- [x] 2.1 新增 `GET /me`：返回当前 JWT 用户完整画像 DTO（`userId/displayName/sex/trainingStartYear/email`），只读幂等；未登录 401。
- [x] 2.2 新增 `PATCH /account/profile`：入参可含 `displayName`/`sex`/`trainingStartYear` 任意子集（PATCH 语义，缺省不改），**带幂等键**（复用 `idempotency` 模块）；校验称呼去空白 1–20、性别枚举、开始年份 1900..当前年；成功返回完整画像。新增 `ProfileService` + DTO。
- [x] 2.3 校验失败经 `AppException` → ProblemDetail（400），确认 `/error` permitAll 不被 403 拦截。
- [x] 2.4 后端单测：`GET /me` 字段完整 + 未登录 401；PATCH 部分更新（仅改一字段其余不动）、幂等（重复键不重复写）、称呼超长 / 空白拒绝、性别枚举、开始年份越界拒绝。

## 3. iOS · 数据模型与网络层

- [x] 3.1 `Models/UserProfile.swift`：`sex` 保持非空默认男，纳入登录回灌覆盖。（训练资历字段已取消，不加。）
- [x] 3.2 新增 `ProfileAPI`：`GET /me` 与 `PATCH /account/profile`（带幂等键）；`ProfileDTO` + `ProfilePatchRequest`（仅称呼 / 性别，合成 Encodable 省略 nil = PATCH 语义）。
- [x] 3.3 `SessionStore`：登录成功后拉 `GET /me`，以服务端值回灌覆盖本地 `UserProfile`（称呼 / 性别，空则保留本地）；暴露 `needsProfileCompletion` 供门控；本地 `sex` 默认值随首次 PATCH 回填。
- [x] 3.4 画像写路径：乐观本地写 + 异步 PATCH，失败置 pending 静默重试（不进 `SyncEngine`）。

## 4. iOS · 设计先行（OpenDesign）

- [x] 4.1 OpenDesign 出「首登资料补全页」高保真稿（`meigei-c-onboarding-profile.html`）：称呼（Apple 预填、必填）+ 性别（男/女、默认男、必填）。训练资历已取消。
- [x] 4.2 OpenDesign 出我的页「个人资料」分组稿（`meigei-c-profile-v2.html`）：称呼行内编辑 + 性别行。
- [x] 4.3 用户确认设计稿（**写码前的硬卡点**）。

## 5. iOS · 首登补全页

- [x] 5.1 `ProfileCompletionView`：称呼（Apple 预填、去空白 1–20 必填）+ 性别（默认男）+「开始训练」按钮（称呼非法时 disabled）。
- [x] 5.2 `RootView` 门控：登录后依 `needsProfileCompletion` 呈现补全页 / 主 App / 加载态（nil 时拉 `GET /me`）；提交成功转入 `MainTabView` 并触发既有注册推送 + `syncAll`。
- [x] 5.3 提交中锁表单 + loading；失败保持页面 + 错误提示 + 重试；弱网用幂等键。

## 6. iOS · 我的页二次编辑

- [x] 6.1 `ProfileView` 新增「个人资料」分组，称呼行点击 → 行内输入框 + 保存/取消（去空白 1–20，非法禁用保存）；保存乐观本地写 + PATCH。顶部 header 称呼保持纯展示。
- [x] 6.2 性别行从「偏好」移入「个人资料」并语义升级：切换即本地切图 + `scheduleProfilePush()` PATCH 回后端。
- [x] 6.3 ProfileHeader 副标由训练龄改为「加入于 {createdAt:yyyy.MM} · 已记录 {总训练} 次」，移除 `trainingYears()` 推算。

## 7. 验证与协同

- [x] 7.1 后端 `./gradlew test` 通过；iOS `xcodebuild` 编译通过。
- [ ] 7.2 端到端联调：首登门控 → 补全 → 后端落库 → 重登 `GET /me` 回灌不再弹页；中途杀 App 再登仍拦；女性用户肌群图正确；换设备读回一致。
- [ ] 7.3 归档前核对：与已归档 `profile-account-deletion-and-prefs` 是否改同一 `profile-ui` requirement，避免归档回退（见 memory「归档 sync 重叠坑」）。
