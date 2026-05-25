### Requirement: 强制深色外观

iOS App SHALL 在顶层 `WindowGroup` 上强制 `.preferredColorScheme(.dark)`，不响应系统浅色/深色切换。MVP 阶段 MUST NOT 提供外观切换设置项。

#### Scenario: 系统切换为浅色
- **WHEN** 用户在 iOS 设置中将系统外观切换为浅色
- **THEN** MeiGei App 内所有界面仍保持深色

### Requirement: Theme Token 命名空间

App 的颜色、字体、间距、圆角 SHALL 以 `Theme.Color.*` / `Theme.Font.*` / `Theme.Spacing.*` / `Theme.Radius.*` 命名空间集中暴露；视图代码 MUST NOT 直接使用颜色字面量（如 `Color(red:...)`、`Color.cyan`）或字号字面量。

#### Scenario: 引用颜色
- **WHEN** 新视图需要主色 CTA 背景
- **THEN** 视图通过 `Theme.Color.accentCyan` 获取色值，不允许在视图内直接构造 `Color`

### Requirement: 等宽数字字体回退

App SHALL 加载 JetBrains Mono 字体用于所有等宽数字展示（训练量、PR、计时器等）。若字体未注册（资源缺失或注入失败），`Theme.Font.mono` MUST 自动回退到 SwiftUI 系统 `.system(.monospaced)`，App MUST NOT 崩溃或显示 fallback 错误字形。

#### Scenario: 字体资源齐全
- **WHEN** App 启动并验证 `JetBrainsMono-Regular` 已注册
- **THEN** 所有 mono 字段以 JetBrains Mono 渲染

#### Scenario: 字体资源缺失
- **WHEN** Bundle 中缺少字体文件
- **THEN** `Theme.Font.mono(size:)` 返回 `.system(size:design:.monospaced)`，DEBUG 构建打印一次 OSLog warning，Release 构建静默回退

### Requirement: 品红色专用语义

`Theme.Color.accentMagenta` MUST 仅用于「Personal Record（PR）」相关视觉元素——包括 PR 卡边光、PR 徽标、新增 PR 文字与 PR 庆祝 toast。视图代码 MUST NOT 将该色用于非 PR 语义（如普通 CTA、普通错误、普通高亮）。

#### Scenario: PR 元素使用品红
- **WHEN** 渲染动作详情的 Personal Record 卡片
- **THEN** 卡片左侧 3px 竖条与外发光使用 `Theme.Color.accentMagenta`

#### Scenario: 非 PR 元素禁用品红
- **WHEN** 渲染普通错误提示或非 PR 类高亮
- **THEN** 必须使用 `Theme.Color.danger`（错误）或 `Theme.Color.accentCyan`（高亮），不得使用 magenta
