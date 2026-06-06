# profile-ui Specification

## Purpose
TBD - created by archiving change redesign-remaining-neon-screens. Update Purpose after archive.
## Requirements
### Requirement: 个人中心顶部 Profile Header

`ProfileView` SHALL 在「我的」tab 顶部渲染 ProfileHeader：左侧 64×64pt 圆形头像（首字母 + hash 配色），右侧两行—大字 `Theme.Font.display(22, .bold)` 用户名 + `Theme.Font.mono` muted 小字「`训练龄 {years} 年`」（训练龄由最早一条 `Workout` 推算）。

#### Scenario: 用户已有训练记录
- **WHEN** `UserProfile` 已登录且存在至少一条 `Workout`
- **THEN** 渲染头像 + 用户名 + 「训练龄 {years} 年」副标。

### Requirement: 三宫格统计

ProfileHeader 下方 SHALL 渲染 1×2 网格：「总训练 / 最长连续」，每格背景 `Theme.Color.surface`，外层 1px `Theme.Color.border` 网格内 1px 分隔，两格数字均使用 `Theme.Color.fg`。原「本月 PR」格 MUST 移除（其依赖的 `PRStats.newPRs()` 随历史模块一并删除）。

#### Scenario: 用户从未训练
- **WHEN** `Workout` 表 0 行
- **THEN** 两格分别显示 `0` / `0d`，不报错不空白。

#### Scenario: 不再展示本月 PR
- **WHEN** 用户进入「我的」页
- **THEN** 顶部统计仅含「总训练」与「最长连续」两格，不渲染「本月 PR」格，布局不留空位。

### Requirement: 设置分组列表

ProfileView SHALL 渲染设置项分组：**数据 · 同步**（含 HealthKit、立即同步两行）。每组顶部为 `sec-h`（uppercase `eyebrow` 样式）。每行左侧为 24×24pt outlined icon + label，右侧为状态 value（`mono` 样式）。HealthKit 为纯展示行（无导航、无 chevron），立即同步为 `SyncRow`（点击触发 `SyncEngine.syncAll`）。「个人信息」「单位」「通知」三项及其二级页 MUST 移除（三者各自留待后续单独立项），其占位目标页 `PlaceholderDetailView` 一并删除；通用导航行组件 `SetItemRow` 因再无调用方 MUST 一并删除。

#### Scenario: 不再展示三个二级入口
- **WHEN** 用户进入「我的」页查看设置分组
- **THEN** 列表不出现「个人信息」「单位」「通知」任一行，亦无指向 `PlaceholderDetailView` 的入口。

#### Scenario: HealthKit 已授权
- **WHEN** HealthKit 已授权
- **THEN** HealthKit 行右侧 value 显示「已连接」并用 `Theme.Color.ok` 文字；未授权时显示「未授权」并用 `Theme.Color.danger` 文字。

#### Scenario: 立即同步进行中
- **WHEN** 用户点击「立即同步」且 `SyncEngine.syncAll` 正在运行
- **THEN** 右侧呈现 `ProgressView` + 「同步中…」文字；空闲时显示「空闲」灰色文字。

### Requirement: 退出登录入口

ProfileView SHALL 在列表底部居中渲染「退出登录」红色文字（`Theme.Color.danger`），点击后弹原生 confirm；确认后调用 `SessionStore.signOut()`。

#### Scenario: 确认退出
- **WHEN** 用户点击「退出登录」并在 confirm 中点「确认」
- **THEN** `SessionStore.signOut()` 被调用，App 跳回 LoginView。

#### Scenario: 取消退出
- **WHEN** 用户点击「退出登录」并在 confirm 中点「取消」
- **THEN** 无副作用。

### Requirement: 登录页视觉规范

`LoginView` SHALL 全屏黑底，以 cyber 网格 + 双 radial gradient（cyan 右上 / magenta 左下）+ 横向 scanline 作为背景。左下区域 SHALL 渲染：3 段彩色色条装饰、`Theme.Font.mono` 小字「MEIGEI · NO.0001」、大标题「认真训练。/ 严肃记录。/ 仅此而已。」最后一行用 `Theme.Color.accentCyan`。底部 SHALL 渲染原生 `SignInWithAppleButton`（黑底白字风格 = `.whiteOutline` 或 `.white`，高 50pt，圆角 13pt），下方 `Theme.Font.mono` 小字法律提示「继续即表示同意 服务条款 与 隐私政策」。

#### Scenario: 用户首次启动
- **WHEN** App 启动且 `SessionStore.isSignedIn == false`
- **THEN** 渲染 LoginView，按钮点击触发 `AuthService.signInWithApple()`。

#### Scenario: 登录中
- **WHEN** Apple 登录请求进行中
- **THEN** 按钮显示 `ProgressView()` 替代文字，禁止重复点击。

#### Scenario: 登录失败
- **WHEN** Apple 登录返回错误（取消除外）
- **THEN** 按钮下方显示 1 行红色错误文字 `Theme.Color.danger`，文本来自 `AppException.message` 或本地兜底「登录失败，请重试」。

