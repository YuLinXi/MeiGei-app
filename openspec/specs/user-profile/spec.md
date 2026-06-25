# user-profile Specification

## Purpose
TBD - created by archiving change first-login-profile-completion. Update Purpose after archive.
## Requirements
### Requirement: 用户画像后端持久化

后端 `app_user` 表 SHALL 持久化用户画像：称呼（复用 `display_name`）、性别（新增 `sex`，**可空**，取值 `male` / `female`，null = 从未设置）。`sex` 不设库层默认值：null 用于区分「用户显式选了男」与「从未填」，使客户端回灌时 null 保留本地、避免服务端默认值覆盖存量本地选择；展示层缺省按男渲染。画像属于**服务端权威域**，MUST NOT 纳入同步 LWW 域（不带 `serverId/localId/version` 同步信封）。Apple 登录后该用户必有一行 `app_user`（首登创建、老用户复用），称呼为空表示画像未补全（与 `sex` 无关）。

#### Scenario: 首登创建用户即有画像行
- **WHEN** 一个新 Apple `sub` 首次登录
- **THEN** 创建 `app_user` 行，`sex` 与 `display_name` 均为空（称呼为空 = 画像未补全）。

#### Scenario: 性别取值受约束
- **WHEN** 写入 `sex`
- **THEN** 仅接受 `male` / `female`，其它值返回 400；未提供时保持原值（不强制落默认）。

#### Scenario: 性别未设置原样回传 null
- **WHEN** `GET /me` 时该用户 `sex` 从未设置
- **THEN** 响应 `sex` 为 null（不兜底为 male），由客户端保留本地值并按男展示。

### Requirement: 读取当前用户画像

后端 SHALL 提供 `GET /me`，返回当前 JWT 用户的画像：`userId`、`displayName`（称呼，可空）、`sex`（可空）、`email`（可空）。该接口为只读、幂等，供登录后回灌客户端与首登门控判定。

#### Scenario: 已登录拉取画像
- **WHEN** 携带有效 JWT 调用 `GET /me`
- **THEN** 返回该用户画像 JSON；`displayName` 为空表示尚未补全称呼。

#### Scenario: 未登录拒绝
- **WHEN** 无有效 JWT 调用 `GET /me`
- **THEN** 返回 401，不泄露任何用户数据。

### Requirement: 修改用户画像

后端 SHALL 提供 `PATCH /account/profile`（带 `Idempotency-Key`，遵守全站写接口幂等铁律）部分更新画像。请求体可含 `displayName` / `sex` 任意子集；缺省字段不改动（PATCH 语义）。称呼非空时 SHALL 校验去除首尾空白后长度 1–20；性别 SHALL 校验枚举 `male`/`female`。校验失败返回 400（经 `AppException` → ProblemDetail）。成功返回更新后的完整画像。

#### Scenario: 部分更新仅改性别
- **WHEN** 用户 PATCH 仅含 `{"sex":"female"}`
- **THEN** 仅 `sex` 改为 `female`，`displayName` 保持原值，返回完整画像。

#### Scenario: 称呼超长被拒
- **WHEN** PATCH 的 `displayName` 去空白后超过 20 字符
- **THEN** 返回 400，画像不变。

#### Scenario: 性别枚举非法被拒
- **WHEN** PATCH 的 `sex` 不是 `male`/`female`
- **THEN** 返回 400，画像不变。

#### Scenario: 幂等重放
- **WHEN** 同一 `Idempotency-Key` 重复提交相同 PATCH
- **THEN** 第二次返回首次的缓存响应，不重复写库。

### Requirement: 首登资料补全门控（客户端判定）

客户端 SHALL 在 Apple 登录成功后拉取 `GET /me`，以**后端画像称呼（`displayName`）是否为空**作为「是否需要补全」的唯一判定，MUST NOT 以 `AuthResponse.newUser` 作唯一信号（用户中途杀 App 会漏判）。称呼为空时强制进入全屏补全页，未提交成功不得进入主 App；称呼非空直接进主 App。存量老用户若称呼从未填过，同样被引导补全。

#### Scenario: 新用户进入补全页
- **WHEN** 登录后 `GET /me` 返回 `displayName` 为空
- **THEN** 路由到全屏首登补全页，主 App 不可达，直至补全提交成功。

#### Scenario: 中途杀 App 仍会补全
- **WHEN** 用户首登进入补全页未提交即杀掉 App，再次登录
- **THEN** `GET /me` 称呼仍为空，再次进入补全页（不因 `newUser=false` 漏判）。

#### Scenario: 老用户已有称呼直接进主 App
- **WHEN** 登录后 `GET /me` 返回非空 `displayName`
- **THEN** 不显示补全页，直接进入主 App。

### Requirement: 首登补全页采集与提交

首登补全页 SHALL 采集称呼与性别两字段并经 `PATCH /account/profile` 一次性提交：

- **称呼**：必填；以 Apple 首登回传的全名预填，可改；去空白后非空且 ≤20 字符方可提交；Apple 隐藏姓名时为空，必须手填。
- **性别**：必填，默认选中「男」（有默认值不阻塞，但作为画像确认项）。

称呼校验未通过时提交按钮 SHALL 禁用。提交中显示加载态并锁定表单防重复提交。提交成功后落地本地画像并进入主 App；提交失败保留页面、提示错误、允许重试。

#### Scenario: 称呼预填来自 Apple 全名
- **WHEN** Apple 首登回传了全名
- **THEN** 补全页称呼输入框预填该全名，用户可直接确认或修改。

#### Scenario: 称呼为空禁止提交
- **WHEN** 称呼输入去空白后为空
- **THEN** 提交按钮禁用，无法进入主 App。

#### Scenario: 提交失败可重试
- **WHEN** 提交 PATCH 因网络失败
- **THEN** 停留补全页、展示错误文案、保留已填内容，允许再次提交。

### Requirement: 画像离线编辑与回填

客户端改画像 SHALL 走**乐观本地写 + REST PATCH**：先即时落地本地 `UserProfile` 并刷新 UI，再异步 `PATCH /account/profile`；失败保持本地值并静默重试，不进 SwiftData 同步信封。登录后 `GET /me` 回灌时，服务端称呼 / 性别非空才覆盖本地（称呼空 = 未补全，保留 Apple 预填；性别空 = 未设置，保留本地默认）；本地已有的 `sex` 默认值在首次 PATCH 时回填后端（存量迁移）。

#### Scenario: 离线改性别即时生效
- **WHEN** 无网络时用户在「我的」页切换性别
- **THEN** 本地 `UserProfile.sex` 即时更新、肌群图随之切换，PATCH 入待重试，恢复网络后补传。

#### Scenario: 登录回灌以服务端为准
- **WHEN** 换设备登录后 `GET /me` 返回 `sex=female`
- **THEN** 本地画像被覆盖为 `female`，不保留旧设备的本地默认值。

#### Scenario: 存量本地默认性别回填后端
- **WHEN** 老用户本地 `sex` 有值而后端从未存过，用户首次触发画像 PATCH
- **THEN** 该 `sex` 值随 PATCH 上送并持久化到后端。

### Requirement: 删除重装后回到登录页（清孤儿登录态）

iOS Keychain 在删除并重装 App 后仍存活，而 SwiftData / UserDefaults 被清空。客户端 SHALL 在「重装 / 全新安装首启」时清除残留 Keychain JWT，使重装后回到登录页、重新走 Apple 登录，MUST NOT 直接以残留 token 判定为已登录。判定「重装首启」SHALL 使用 UserDefaults 哨兵位（随重装清空、Keychain 不清空，故哨兵缺失等价于重装首启）。称呼随重新登录后的 `GET /me` 回填，MUST NOT 因 SwiftData 被清空而误弹补全页。

#### Scenario: 重装后回到登录页
- **WHEN** 用户已登录并补全称呼，删除 App 后重装并冷启动
- **THEN** 检测到 UserDefaults 哨兵缺失（重装首启），清除残留 Keychain JWT，显示登录页要求重新 Apple 登录，而非直接进入主 App 或补全页。

#### Scenario: 正常重启不清 token
- **WHEN** 已安装的 App 正常退出后再启动（哨兵位存在）
- **THEN** 保留 Keychain JWT，维持登录态，不要求重新登录。

### Requirement: 登录态对失效 token 的防御

客户端 MUST NOT 把「Keychain 存在 token」无条件视为有效登录态而不设任何失效兜底。任何 REST 请求返回 401（token 过期 / 失效）SHALL 触发登出（清 Keychain JWT 并回到登录页），杜绝「token 在但所有请求 401」的幽灵态。首登补全页 SHALL 提供「退出登录 / 换账号」出口，作为任何异常态（含失效 token 被路由到补全页）的兜底逃生，避免无出口死锁。

#### Scenario: 请求遇 401 自动登出
- **WHEN** 任一携带 JWT 的 REST 请求返回 401
- **THEN** 客户端清除本地登录态并回到登录页，不停留在功能不可用的已登录界面。

#### Scenario: 补全页可退出
- **WHEN** 用户处于首登补全页
- **THEN** 页面提供「退出登录 / 换账号」入口，点击后清登录态回到登录页，不被无出口的补全页困住。

### Requirement: 画像拉取失败不误判为未补全

客户端判定「是否需要补全」时 SHALL 严格区分「`GET /me` 成功且称呼确为空」与「`GET /me` 失败（网络 / 401 / 超时）」。仅前者 SHALL 判定需要补全并路由到补全页；后者 MUST NOT 据此判定需补全（不得因本地无数据就误弹补全页），应停留在加载态并重试 / 兜底。

#### Scenario: 拉取失败不弹补全页
- **WHEN** 登录后 `GET /me` 因网络或超时失败，且本地无画像（如刚重装）
- **THEN** 客户端停留在加载态并重试，MUST NOT 路由到补全页，避免把「拿不到服务端数据」误判成「用户未填称呼」。

#### Scenario: 拉取成功且称呼空才补全
- **WHEN** `GET /me` 成功返回且 `displayName` 去空白后为空
- **THEN** 路由到补全页（此为唯一判定需补全的条件）。

