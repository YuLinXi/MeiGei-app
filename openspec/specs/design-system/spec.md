## Purpose

Neon Design System：以黑底霓虹辉光、JetBrains Mono 等宽数字、`Theme.*` token 与少量 Modifier 组合，为 DontLift 提供「严肃健身工具」的统一视觉系统。
## Requirements
### Requirement: 强制深色外观

iOS App SHALL 在顶层 `WindowGroup` 上强制 `.preferredColorScheme(.dark)`，不响应系统浅色/深色切换。MVP 阶段 MUST NOT 提供外观切换设置项。

#### Scenario: 系统切换为浅色
- **WHEN** 用户在 iOS 设置中将系统外观切换为浅色
- **THEN** DontLift App 内所有界面仍保持深色

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

### Requirement: 禁用 List/Form 顶层容器

新视图（本 change 涉及的 9 屏及未来同风格视图）MUST NOT 使用 SwiftUI `List` 或 `Form` 作为顶层滚动容器。若因功能必要（如系统级 swipe-to-delete）必须使用，MUST 通过 `.scrollContentBackground(.hidden)` + `.background(Theme.Color.bg)` 隐藏 iOS 默认浅灰背景，并在视图代码注释中标注「必要的 List 用法」原因。

#### Scenario: 新增设置类视图
- **WHEN** 新增 `ProfileView` 或同类设置 / 列表视图
- **THEN** 顶层使用 `ScrollView { LazyVStack { ... } }`，分组用自绘 `eyebrow` + `cardStyle()` 容器；不出现 `List` / `Form`。

#### Scenario: 必须使用 List 的边缘场景
- **WHEN** 某视图必须使用 List（如需要原生 swipe action）
- **THEN** 视图 MUST 调 `.scrollContentBackground(.hidden).background(Theme.Color.bg)`，且文件注释解释为何无法用自绘 VStack。

### Requirement: 横向 Chip 选择器组件

设计系统 SHALL 提供 `HorizontalChipPicker<Item: Identifiable>` 组件：水平 `ScrollView` + `HStack(spacing: Theme.Spacing.sm)` + 每个 chip 高 32pt、横 padding 14pt、`Theme.Radius.pill` 圆角。选中态背景 `Theme.Color.accentCyan` + `Theme.Color.accentInk` 文字 + `.neonGlow(.cyan, .sm)`；未选中态背景 `Theme.Color.surface` + 1pt `Theme.Color.border` + `Theme.Color.fg2` 文字。

#### Scenario: 动作库部位筛选
- **WHEN** ExerciseLibraryView 渲染部位筛选 chips
- **THEN** 使用 `HorizontalChipPicker`，传入 `[全部, 胸, 背, 腿, 肩, 手臂, 核心]`，默认选中第 0 个。

### Requirement: 统一触感反馈封装

设计系统 SHALL 提供 `Theme.Haptics` 命名空间，统一暴露 `impact(_:)`（轻 / 中 / 重碰撞）、`selection()`（选择切换）、`notification(_:)`（成功 / 警告 / 失败）三类触感方法，内部封装对应的 `UIImpactFeedbackGenerator` / `UISelectionFeedbackGenerator` / `UINotificationFeedbackGenerator`。视图代码 MUST NOT 直接 new `UI*FeedbackGenerator`，而 SHALL 通过 `Theme.Haptics` 触发；已有裸调用（如休息计时弹窗）MUST 迁移至该封装。

#### Scenario: 触发关键动作触感
- **WHEN** 用户点击「开始训练」CTA
- **THEN** 通过 `Theme.Haptics.impact(.medium)` 触发一次中等强度触感

#### Scenario: 收敛既有裸调用
- **WHEN** 休息计时弹窗触发「手机震动」或「完成」
- **THEN** 改由 `Theme.Haptics` 触发，不再直接构造 `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator`

### Requirement: 按压交互样式

设计系统 SHALL 提供可复用的 `PressableButtonStyle: ButtonStyle`：按下时 `scaleEffect(0.97)` + 轻微降低不透明度，动画时长 100–200ms。缩放 MUST 收敛在不引发布局位移的幅度（≥0.95）。该样式 MUST 读取 `@Environment(\.accessibilityReduceMotion)`，开启「减弱动态效果」时 MUST 退化为仅不透明度变化、不做缩放。

#### Scenario: 普通按压反馈
- **WHEN** 用户按下采用 `PressableButtonStyle` 的卡片或 CTA
- **THEN** 按钮在按下期间轻微缩小并降低不透明度，松手平滑还原，不引起周边布局跳动

#### Scenario: 减弱动态效果时
- **WHEN** 系统「减弱动态效果」开启，用户按下同一按钮
- **THEN** 仅不透明度变化，无缩放动画

### Requirement: 动效降级与 Dynamic Type 防截断基线

设计系统中持续性 / 重复性动效（如 `repeatForever` 脉冲、持续辉光、`spring` 过渡）MUST 在 `@Environment(\.accessibilityReduceMotion)` 开启时退化为静态或淡入淡出。固定字号文本在易截断处 SHALL 配置 `minimumScaleFactor` 与合理 `lineLimit`，保证在系统放大字号（Dynamic Type）下不溢出、不破版。

#### Scenario: 减弱动态效果关闭重复动画
- **WHEN** 用户开启「减弱动态效果」并进入含 LIVE 脉冲 / 辉光的界面
- **THEN** 脉冲与持续辉光停止重复，呈现为静态样式

#### Scenario: 超大动态字号
- **WHEN** 用户将系统字号调至较大档位并浏览首页
- **THEN** 标题与副标文本按 `minimumScaleFactor` 适度缩放或截断，不超出卡片、不与相邻元素重叠

