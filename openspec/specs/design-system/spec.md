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

### Requirement: 统一圆形图标按钮

设计系统 SHALL 提供唯一的圆形图标按钮组件 `CircleIconButton`，作为所有 Header / 导航栏中「返回 / 更多操作 / 次级图标动作」的单一来源；视图代码 MUST NOT 在页面内本地复制等价实现（如自绘 `navCircle`、自绘 Menu 圆形 label）。

- 默认直径 SHALL 为 36pt（导航类圆钮与主操作钮 `CircleAddButton` 直径对齐）。
- 图标字号 SHALL 由组件按统一规则从直径推导，MUST NOT 在调用点硬编码图标字号；同一直径下所有圆钮的图标视觉重量一致。
- 外观为白底（`Theme.Color.surface`）+ 1pt `Theme.Color.border` 描边 + 圆形，按压走 `PressableButtonStyle`。
- SHALL 支持 `active` 高亮态（选中/展开时用 `Theme.Color.accent` 前景 + `Theme.Color.accentSoft` 底 + `Theme.Color.accentSofter` 描边）与 `rotated` 旋转态（如 ⋯ 展开时旋转 90°）。
- SHALL 提供 Menu 版入口：以同一外观 label 包裹 SwiftUI `Menu`，确保「点击触发」与「弹出菜单」两类圆钮视觉完全一致。

#### Scenario: 子页接入返回按钮

- **WHEN** 任一 push/sheet 子页需要返回按钮
- **THEN** 使用 `CircleIconButton(systemName: "chevron.left", …)`，直径 36pt，图标字号由组件推导，外观为纸感白底圆形
- **AND** 不出现系统默认蓝色返回箭头

#### Scenario: 更多操作菜单圆钮

- **WHEN** Header 右侧需要「⋯ 更多操作」弹出菜单
- **THEN** 使用 `CircleIconButton` 的 Menu 版，其外观与点击触发版完全一致
- **AND** 菜单展开时圆钮进入 `active` + `rotated` 态

#### Scenario: 禁止本地复制实现

- **WHEN** 新增或修改任意页面的 Header 圆形按钮
- **THEN** 复用 `CircleIconButton`，MUST NOT 在该页内重新声明等价的圆形按钮外观函数

### Requirement: 统一子页 Header 容器

设计系统 SHALL 提供子页（push/sheet 二级及以上页面）的 Header 容器 `PaperNavBar`（或等价的 `.paperToolbar()` 修饰符），封装以下职责，使各子页以单一接入点获得一致的导航栏：

- 隐藏系统默认返回按钮（`navigationBarBackButtonHidden(true)`）。
- 在 iOS 26+ 对工具栏按钮施加 `sharedBackgroundVisibility(.hidden)`，消除 Liquid Glass 自动圆形背景与纸感圆钮叠成的「双环」；低于 iOS 26 走等价无背景分支。
- 提供左（返回）/ 中（标题）/ 右（操作）三槽位；左、右槽位默认承载 `CircleIconButton`。
- 标题 SHALL 使用单一字体 token（取代既有系统 inline / `body(15,heavy)` / `display(30)` 等并存写法），居中、单行截断。

所有 push/sheet 子页的标题栏 MUST 经由该容器实现；MUST NOT 直接散用裸 `.toolbar { … }` + 手搓圆钮 + 逐 `ToolbarItem` 打 `sharedBackgroundVisibility` 补丁的旧写法。Tab 根页（训练 / 计划 / 动作 / Team / 我的）的自绘大标题范式不受此要求约束——其中「我的」(`ProfileView`) 作为 Tab 根页（无返回箭头）SHALL 归入自绘大标题范式（`display(36, heavy)`），不走 `.paperToolbar()`。

#### Scenario: 子页统一接入

- **WHEN** `WorkoutDetailView` / `PlanDetailView` / `TeamDetailView` / `ExerciseDetailView` / `TeamPlansView`（push/sheet 子页）渲染顶部标题栏
- **THEN** 均经由 `.paperToolbar()` 接入，标题字体一致、返回/操作钮均为 36pt 纸感圆钮
- **AND** 不再各自处理 `navigationBarBackButtonHidden` 与 iOS 26 双环补丁

#### Scenario: 我的页归入大标题范式

- **WHEN** Tab 根页「我的」(`ProfileView`) 渲染顶部
- **THEN** 用自绘大标题「我的」`display(36, heavy)` + `tracking(-1.08)`、隐藏系统导航栏，与其它 4 个 Tab 根页一致
- **AND** 不出现系统 inline 居中标题

#### Scenario: iOS 26 不出现双环

- **WHEN** 在 iOS 26+ 设备上进入任一接入了 `PaperNavBar` 的子页
- **THEN** Header 圆钮仅显示纸感白底圆形一层背景，不出现系统 Liquid Glass 叠加的第二层圆环

#### Scenario: 子页标题字体统一

- **WHEN** 任意子页显示标题文字
- **THEN** 使用容器约定的单一标题字体 token，跨子页字号、字重一致

