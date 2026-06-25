# profile-ui Specification

## Purpose
TBD - created by archiving change redesign-remaining-neon-screens. Update Purpose after archive.
## Requirements
### Requirement: 个人中心顶部 Profile Header

`ProfileView` SHALL 在「我的」tab 顶部渲染 ProfileHeader：左侧 64×64pt 圆形头像（首字母 + 主色调朱砂红底），右侧两行—大字 `Theme.Font.display(22, .bold)` 称呼 + `Theme.Font.mono` muted 小字副标。

**称呼纯展示、不在顶部编辑**：顶部称呼只展示，编辑统一进「个人资料」分组（见「用户资料编辑分组」）。

**副标内容**：副标 SHALL 显示「加入于 {createdAt:yyyy.MM} · 已记录 {总训练次数} 次」，不再展示训练龄 / 训练年限（该字段已不采集）。`createdAt` 缺失时退化为「已记录 {n} 次」。

#### Scenario: 渲染头像与副标
- **WHEN** 用户进入「我的」页且本地有 `UserProfile`
- **THEN** 渲染头像 + 称呼 + 副标「加入于 {月份} · 已记录 {n} 次」。

#### Scenario: 顶部称呼不可编辑
- **WHEN** 用户点击顶部 ProfileHeader 的称呼
- **THEN** 不进入编辑（顶部仅展示）；编辑入口在「个人资料」分组内。

### Requirement: 训练统计卡

ProfileHeader 下方 SHALL 渲染单个全宽统计卡：「总训练」。该统计卡背景为 `Theme.Color.surface`（白），外层 1px `Theme.Color.border`，数字使用 `Theme.Color.fg`。原「本月 PR」格 MUST 保持移除，且 MUST NOT 展示「最长连续」。

#### Scenario: 用户从未训练
- **WHEN** `Workout` 表 0 行
- **THEN** 统计卡显示「总训练 0」，不报错不空白。

#### Scenario: 不再展示本月 PR 与最长连续
- **WHEN** 用户进入「我的」页
- **THEN** 顶部统计仅含「总训练」
- **AND** 不渲染「本月 PR」或「最长连续」格，布局不留空位

### Requirement: 设置分组列表

ProfileView SHALL 渲染设置项分组:**数据 · 同步**(含 HealthKit、立即同步两行)。每组顶部为 `sec-h`(uppercase `eyebrow` 样式)。每行左侧为 24×24pt outlined icon + label,右侧为状态 value(`mono` 样式)。**HealthKit 行 SHALL 改为可发起授权的活行**:未授权时点击触发 HealthKit 授权请求,授权态(已连接 / 未授权)随之实时更新;立即同步为 `SyncRow`(点击触发 `SyncEngine.syncAll`)。「个人信息」「单位」「通知」三项及其二级页此前已移除,本组不恢复(单位与通知偏好另见「训练偏好分组」)。

#### Scenario: HealthKit 未授权可发起授权
- **WHEN** HealthKit 未授权且用户点击 HealthKit 行
- **THEN** 发起系统 HealthKit 授权请求;用户授权后该行 value 变为「已连接」(`Theme.Color.ok`)。

#### Scenario: HealthKit 已授权展示
- **WHEN** HealthKit 已授权
- **THEN** HealthKit 行 value 显示「已连接」并用 `Theme.Color.ok` 文字;未授权时显示「未授权」并用 `Theme.Color.danger` 文字。

#### Scenario: 立即同步进行中
- **WHEN** 用户点击「立即同步」且 `SyncEngine.syncAll` 正在运行
- **THEN** 右侧呈现 `ProgressView` + 「同步中…」文字;空闲时显示「空闲」灰色文字。

### Requirement: 退出登录入口

ProfileView SHALL 在「账号」分组内渲染「退出登录」(`Theme.Color.danger` 红字),点击后弹 `paperConfirmDialog`;确认后调用 `SessionStore.logout()`(保留本地数据,下次登录后继续同步)。「退出登录」与「删除账号」语义不同:退出仅清登录态、保留本地数据;删除账号永久清除数据(见「账号分组与删除账号入口」)。

#### Scenario: 确认退出
- **WHEN** 用户点击「退出登录」并在确认对话框点「退出登录」
- **THEN** `SessionStore.logout()` 被调用,本地数据保留,App 跳回 LoginView。

#### Scenario: 取消退出
- **WHEN** 用户点击「退出登录」并在确认对话框点「取消」
- **THEN** 无副作用。

### Requirement: 登录页视觉规范

`LoginView` SHALL 全屏纸白底（`Theme.Color.bg`），以大面积留白 + 极简排版呈现，MUST NOT 使用赛博网格、radial gradient 或 scanline 背景。顶部区域 SHALL 渲染品牌标识：方形「M」标记 + `Theme.Font.mono` 小字「DONTLIFT · NO.0001」。中部/下部 SHALL 渲染大标题「认真训练。/ 严肃记录。/ 仅此而已。」（`Theme.Color.fg`，可单行用 `accent` 点缀）+ 一行说明副标（`fg2`）。底部 SHALL 渲染原生 `SignInWithAppleButton`（黑底白字 `.black` 风格，高 50pt，圆角 `Theme.Radius.md`=13pt），下方 `Theme.Font.mono` 小字法律提示「继续即表示同意 服务条款 与 隐私政策」。法律提示中的「服务条款」与「隐私政策」SHALL 为**可点击**控件，点击经 `SFSafariViewController` 打开与「我的 / 关于」组相同的后端页面 URL（配置项，不再是 `/* 文档链接占位 */`）。DevConfig 启用时 SHALL 渲染开发者快捷登录入口。

#### Scenario: 用户首次启动
- **WHEN** App 启动且 `SessionStore.isSignedIn == false`
- **THEN** 渲染纸感 LoginView（纸白底、无赛博网格），按钮点击触发 `AuthService.signInWithApple()`。

#### Scenario: 登录中
- **WHEN** Apple 登录请求进行中
- **THEN** 按钮显示 `ProgressView()` 替代文字,禁止重复点击。

#### Scenario: 登录失败
- **WHEN** Apple 登录返回错误(取消除外)
- **THEN** 按钮下方显示 1 行红色错误文字 `Theme.Color.danger`,文本来自 `AppException.message` 或本地兜底「登录失败,请重试」。

#### Scenario: 点击法律链接打开页面
- **WHEN** 用户点击登录页法律提示中的「服务条款」或「隐私政策」
- **THEN** 经 `SFSafariViewController` 打开对应页面,不中断登录流程。

### Requirement: 训练偏好分组

ProfileView SHALL 渲染「训练偏好」分组(`groupCard`,顶部 `eyebrow` 标题),含三行:

- **默认休息时长**:读写 `RestTimer.defaultDuration`(持久化于 UserDefaults,默认 90s),通过 stepper/picker 调整,右侧 `mono` value 显示当前秒数;调整即时落盘,后续启动休息计时取该值。
- **震动**:读写 `RestTimer.hapticsEnabled`(UserDefaults,默认开)的开关,控制休息结束/完成时前台震动。
- **通知**:展示系统通知授权态(`mono` value),点击跳转系统设置(`UIApplication.openSettingsURLString`)。

本组**不引入**单位 kg/lb 切换与细粒度通知开关(见 proposal Non-goals)。

#### Scenario: 调整默认休息时长并持久化
- **WHEN** 用户在「默认休息时长」行将值由 90s 改为 120s
- **THEN** `RestTimer.defaultDuration` 更新为 120 并写入 UserDefaults,下次发起组间休息以 120s 起算。

#### Scenario: 切换震动开关
- **WHEN** 用户关闭「震动」开关
- **THEN** `RestTimer.hapticsEnabled` 置为 false 并持久化,休息结束时不再前台震动。

#### Scenario: 通知未授权跳系统设置
- **WHEN** 系统通知未授权,用户点击「通知」行
- **THEN** value 显示未授权态,点击跳转至系统设置页。

### Requirement: 关于组隐私政策与服务条款入口

「关于」分组 SHALL 在「版本」行之外新增「隐私政策」与「服务条款」两行,每行左侧 24×24pt outlined icon + label,点击经 `SFSafariViewController` 打开后端已上线的对应页面 URL(隐私政策位于 `dontlift.peipadada.com`)。URL 作为配置项,MUST NOT 硬编码散落多处。

#### Scenario: 打开隐私政策
- **WHEN** 用户点击「关于」组的「隐私政策」行
- **THEN** 经 `SFSafariViewController` 打开隐私政策页面,不离开 App。

#### Scenario: 打开服务条款
- **WHEN** 用户点击「关于」组的「服务条款」行
- **THEN** 经 `SFSafariViewController` 打开服务条款页面。

### Requirement: 账号分组与删除账号入口

ProfileView SHALL 渲染「账号」分组,含「退出登录」与「删除账号」两项,「删除账号」用 `Theme.Color.danger` 红字。点击「删除账号」SHALL 先拉取 `GET /account/deletion-impact`,再弹二次确认 `paperConfirmDialog`,文案明确告知**账号与全部数据将被永久删除、不可恢复**,并显式列出**将解散的团队数与受影响成员数**;用户确认后 SHALL 触发 `account-deletion` 客户端删号流程(调用删除接口、成功后清本地并登出)。删除进行中入口呈加载态并禁止重复触发。

#### Scenario: 点击删除账号弹二次确认
- **WHEN** 用户点击「删除账号」
- **THEN** 先拉取删号影响面,弹出强调不可恢复的二次确认对话框,显示「将解散 N 个团队、影响 M 名成员」,并提供「删除账号」(danger)与「取消」。

#### Scenario: 确认后触发删号流程
- **WHEN** 用户在确认对话框点「删除账号」
- **THEN** 触发 `account-deletion` 客户端流程,入口呈加载态;成功后 App 回到 LoginView。

#### Scenario: 取消删除无副作用
- **WHEN** 用户在确认对话框点「取消」
- **THEN** 无任何删除发生,停留在「我的」页。

### Requirement: 用户资料编辑分组

ProfileView SHALL 在「我的」页统计网格之下、其它设置分组之上渲染「个人资料」分组（`groupCard` + 行式布局），含称呼与性别两行，二者均为**用户资料**，编辑即乐观本地写并 `PATCH /account/profile`（非纯本地偏好）：

- **称呼**：默认展示当前称呼 + chevron；点击该行 → **行内展开输入框**（聚焦态朱砂红描边）+「保存 / 取消」；约束去空白 1–20 字，非法时保存禁用并提示；保存即乐观本地写 + PATCH。
- **性别**：行内两枚 `male` / `female` 胶囊（朱砂红选中态），点击切换；切换 SHALL 同时驱动肌群高亮图底图并 PATCH 回后端。语义由旧版「纯本地偏好（仅切图）」升级为「资料 + 顺带切图」单一字段，原「偏好」分组移除。

#### Scenario: 称呼行内编辑保存
- **WHEN** 用户点击称呼行、改为合法值并点「保存」
- **THEN** 行内编辑收起、展示新称呼，本地即时更新并 `PATCH /account/profile`；称呼空或超 20 字时「保存」禁用。

#### Scenario: 取消称呼编辑
- **WHEN** 用户在称呼编辑态点「取消」
- **THEN** 收起编辑、丢弃草稿，称呼不变、无网络请求。

#### Scenario: 切换性别即时切图并上行
- **WHEN** 用户在个人资料分组切换性别
- **THEN** 本地 `UserProfile.sex` 即时更新、肌群图随之切换，并异步 `PATCH /account/profile`（失败静默重试）。

### Requirement: 登录后首登补全页路由

`RootView` SHALL 在 `SessionStore.isLoggedIn` 为真后，依据后端画像称呼是否为空决定路由：称呼为空 → 全屏首登补全页（覆盖主 App，不可绕过）；称呼非空 → `MainTabView`；门控信号尚未拉取（nil）时渲染纸白加载态并触发 `GET /me`。补全页提交成功后 SHALL 自动转入 `MainTabView`。该判定以 `GET /me` 结果为准，不以 `AuthResponse.newUser` 为唯一信号。

#### Scenario: 称呼为空展示补全页
- **WHEN** 登录后画像称呼为空
- **THEN** `RootView` 渲染全屏补全页，`MainTabView` 不可见。

#### Scenario: 冷启动拉取画像期间加载态
- **WHEN** 冷启动已登录但门控信号尚未就绪
- **THEN** 渲染纸白加载态并拉 `GET /me`，据结果再路由到补全页或主界面。

#### Scenario: 补全成功进入主界面
- **WHEN** 用户在补全页成功提交
- **THEN** `RootView` 切换为 `MainTabView`，并触发既有的注册推送与 `syncAll`。

#### Scenario: 已补全直接进主界面
- **WHEN** 登录后画像称呼非空
- **THEN** 跳过补全页，直接渲染 `MainTabView`。

### Requirement: 法律入口使用独立 URL

登录页与「我的 → 关于」分组中的「隐私政策」和「服务条款」入口 SHALL 使用独立配置项，并 MUST 指向不同 HTTPS URL。服务条款入口 MUST NOT 复用隐私政策 URL。若任一 URL 缺失或不可构造，DEBUG 构建 SHALL 明确暴露配置错误，Release 构建 MUST 使用已配置的线上 URL。

#### Scenario: 登录页服务条款打开独立页面
- **WHEN** 未登录用户点击登录页「服务条款」
- **THEN** App 打开 `termsOfServiceURL`
- **AND** 该 URL 不等于 `privacyPolicyURL`

#### Scenario: 关于页隐私政策打开隐私页面
- **WHEN** 已登录用户点击「我的 → 关于 → 隐私政策」
- **THEN** App 打开 `privacyPolicyURL`

#### Scenario: 关于页服务条款打开条款页面
- **WHEN** 已登录用户点击「我的 → 关于 → 服务条款」
- **THEN** App 打开 `termsOfServiceURL`
- **AND** 该 URL 不等于 `privacyPolicyURL`

