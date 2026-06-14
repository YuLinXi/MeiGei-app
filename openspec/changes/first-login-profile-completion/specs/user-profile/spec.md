## ADDED Requirements

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
