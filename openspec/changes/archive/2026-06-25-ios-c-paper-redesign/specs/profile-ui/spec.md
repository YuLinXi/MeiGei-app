## MODIFIED Requirements

### Requirement: 登录页视觉规范

`LoginView` SHALL 全屏纸白底（`Theme.Color.bg`），以大面积留白 + 极简排版呈现，MUST NOT 使用赛博网格、radial gradient 或 scanline 背景。顶部区域 SHALL 渲染品牌标识：方形「M」标记 + `Theme.Font.mono` 小字「DONTLIFT · NO.0001」。中部/下部 SHALL 渲染大标题「认真训练。/ 严肃记录。/ 仅此而已。」（`Theme.Color.fg`，可单行用 `accent` 点缀）+ 一行说明副标（`fg2`）。底部 SHALL 渲染原生 `SignInWithAppleButton`（黑底白字 `.black` 风格，高 50pt，圆角 `Theme.Radius.md`=13pt），下方 `Theme.Font.mono` 小字法律提示「继续即表示同意 服务条款 与 隐私政策」，并在 DevConfig 启用时渲染开发者快捷登录入口。

#### Scenario: 用户首次启动
- **WHEN** App 启动且 `SessionStore.isSignedIn == false`
- **THEN** 渲染纸感 LoginView（纸白底、无赛博网格），按钮点击触发 `AuthService.signInWithApple()`。

#### Scenario: 登录中
- **WHEN** Apple 登录请求进行中
- **THEN** 按钮显示 `ProgressView()` 替代文字，禁止重复点击。

#### Scenario: 登录失败
- **WHEN** Apple 登录返回错误（取消除外）
- **THEN** 按钮下方显示 1 行红色错误文字 `Theme.Color.danger`，文本来自 `AppException.message` 或本地兜底「登录失败，请重试」。

### Requirement: 个人中心顶部 Profile Header

`ProfileView` SHALL 在「我的」tab 顶部渲染 ProfileHeader：左侧 64×64pt 圆形头像（首字母 + hash 配色，背景取自纸感调色板）、右侧两行—大字 `Theme.Font` L1 用户名（`fg`） + `Theme.Font.mono` muted 小字「`训练龄 {years} 年`」（训练龄由最早一条 `Workout` 推算）。

#### Scenario: 用户已有训练记录
- **WHEN** `UserProfile` 已登录且存在至少一条 `Workout`
- **THEN** 渲染头像 + 用户名 + 「训练龄 {years} 年」副标（纸感配色）。

### Requirement: 训练统计卡

ProfileHeader 下方 SHALL 渲染单个全宽统计卡：「总训练」。该统计卡背景为 `Theme.Color.surface`（白），外层 1px `Theme.Color.border`，数字使用 `Theme.Color.fg`。原「本月 PR」格 MUST 保持移除，且 MUST NOT 展示「最长连续」。

#### Scenario: 用户从未训练
- **WHEN** `Workout` 表 0 行
- **THEN** 统计卡显示「总训练 0」，不报错不空白。

#### Scenario: 不再展示本月 PR 与最长连续
- **WHEN** 用户进入「我的」页
- **THEN** 顶部统计仅含「总训练」
- **AND** 不渲染「本月 PR」或「最长连续」格，布局不留空位。
