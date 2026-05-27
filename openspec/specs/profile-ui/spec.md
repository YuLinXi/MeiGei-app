# profile-ui Specification

## Purpose
TBD - created by archiving change redesign-remaining-neon-screens. Update Purpose after archive.
## Requirements
### Requirement: 个人中心顶部 Profile Header

`ProfileView` SHALL 在「我的」tab 顶部渲染 ProfileHeader：左侧 64×64pt 圆形头像（首字母 + hash 配色），右侧两行—大字 `Theme.Font.display(22, .bold)` 用户名 + `Theme.Font.mono` muted 小字「`{体重}kg · {身高}cm · 训练龄 {years} 年`」。

#### Scenario: 用户已填写完整资料
- **WHEN** `UserProfile` 字段全部非空
- **THEN** 渲染头像 + 用户名 + 完整副标。

#### Scenario: 用户未填写身高体重
- **WHEN** `UserProfile.weightKg` 或 `heightCm` 为 nil
- **THEN** 副标缺失字段以 `--` 占位（如「-- · 178cm · 训练龄 3 年」）。

### Requirement: 三宫格统计

ProfileHeader 下方 SHALL 渲染 1×3 网格：「总训练 / 本月 PR / 最长连续」，每格背景 `Theme.Color.surface`，外层 1px `Theme.Color.border` 网格内 1px 分隔。本月 PR 数字 MUST 使用 `Theme.Color.accentCyan`，其余两格数字使用 `Theme.Color.fg`。

#### Scenario: 用户从未训练
- **WHEN** `Workout` 表 0 行
- **THEN** 三格分别显示 `0` / `0` / `0d`，不报错不空白。

#### Scenario: 用户本月命中 PR
- **WHEN** 本月内 PR 计数 = 12
- **THEN** 中间格大字 `12` 以 `Theme.Color.accentCyan` 渲染。

### Requirement: 设置分组列表

ProfileView SHALL 渲染至少 3 组设置项：**账户**（个人信息 / 体重围度 / 训练目标）、**数据 · 同步**（立即同步 / HealthKit / 导出数据）、**偏好**（外观 / 通知 / 单位）。每组顶部为 `sec-h`（uppercase `eyebrow` 样式），每项为 `SetItemRow`：左 24×24pt outlined icon + label + 可选 right value（muted）+ 右 chevron。

#### Scenario: HealthKit 已授权
- **WHEN** HealthKit 已授权
- **THEN** HealthKit 行右侧 value 显示「已连接」并用 `Theme.Color.ok` 文字。

#### Scenario: 立即同步进行中
- **WHEN** 用户点击「立即同步」且 `SyncEngine.syncAll` 正在运行
- **THEN** value 切换为「同步中…」灰色文字，完成后切到「已同步 {N} 分钟前」绿色文字。

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

