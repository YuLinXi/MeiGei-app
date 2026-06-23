# profile-ui Specification

## Purpose
TBD - created by archiving change redesign-remaining-neon-screens. Update Purpose after archive.
## Requirements
### Requirement: 个人中心顶部 Profile Header

`ProfileView` SHALL 在「我的」tab 顶部渲染 ProfileHeader：左侧 64×64pt 圆形头像（首字母 + hash 配色），右侧两行—大字 `Theme.Font.display(22, .bold)` 用户名 + `Theme.Font.mono` muted 小字「`训练龄 {years} 年`」（训练龄由最早一条 `Workout` 推算）。

#### Scenario: 用户已有训练记录
- **WHEN** `UserProfile` 已登录且存在至少一条 `Workout`
- **THEN** 渲染头像 + 用户名 + 「训练龄 {years} 年」副标。

### Requirement: 训练统计卡

ProfileHeader 下方 SHALL 渲染单个全宽统计卡：「总训练」。该统计卡背景为 `Theme.Color.surface`，外层 1px `Theme.Color.border`，数字使用 `Theme.Color.fg`。App MUST NOT 展示或计算「最长连续」指标。原「本月 PR」格 MUST 移除（其依赖的 `PRStats.newPRs()` 随历史模块一并删除）。

#### Scenario: 用户从未训练
- **WHEN** `Workout` 表 0 行
- **THEN** 统计卡显示「总训练 0」，不报错不空白。

#### Scenario: 不再展示本月 PR 与最长连续
- **WHEN** 用户进入「我的」页
- **THEN** 顶部统计仅含「总训练」
- **AND** 不渲染「本月 PR」或「最长连续」格，布局不留空位。

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

`LoginView` SHALL 全屏黑底,以 cyber 网格 + 双 radial gradient(cyan 右上 / magenta 左下)+ 横向 scanline 作为背景。左下区域 SHALL 渲染:3 段彩色色条装饰、`Theme.Font.mono` 小字「DONTLIFT · NO.0001」、大标题「认真训练。/ 严肃记录。/ 仅此而已。」最后一行用 `Theme.Color.accentCyan`。底部 SHALL 渲染原生 `SignInWithAppleButton`(黑底白字风格 = `.whiteOutline` 或 `.white`,高 50pt,圆角 13pt),下方 `Theme.Font.mono` 小字法律提示「继续即表示同意 服务条款 与 隐私政策」。法律提示中的「服务条款」与「隐私政策」SHALL 为**可点击**控件,点击经 `SFSafariViewController` 打开与「我的 / 关于」组相同的后端页面 URL(配置项,不再是 `/* 文档链接占位 */`)。

#### Scenario: 用户首次启动
- **WHEN** App 启动且 `SessionStore.isSignedIn == false`
- **THEN** 渲染 LoginView,按钮点击触发 `AuthService.signInWithApple()`。

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
