## Purpose

Paper Design System：以纸白底、近黑文字、朱砂红单点强调、JetBrains Mono 等宽数字、`Theme.*` token 与少量 Modifier 组合，为 DontLift 提供「严肃健身工具」的统一视觉系统。
## Requirements
### Requirement: 强制浅色外观

iOS App SHALL 在顶层 `WindowGroup` 上强制 `.preferredColorScheme(.light)`，不响应系统浅色/深色切换。MVP 阶段 MUST NOT 提供外观切换设置项。纸感极简视觉以纸白底（`#f4f2ec`）+ 近黑文字（`#1c1a17`）+ 朱砂红单点强调（`#d9482b`）呈现。

#### Scenario: 系统切换为深色
- **WHEN** 用户在 iOS 设置中将系统外观切换为深色
- **THEN** DontLift App 内所有界面仍保持纸感浅色

### Requirement: Theme Token 命名空间

App 的颜色、字体、间距、圆角 SHALL 以 `Theme.Color.*` / `Theme.Font.*` / `Theme.Spacing.*` / `Theme.Radius.*` 命名空间集中暴露；视图代码 MUST NOT 直接使用颜色字面量（如 `Color(red:...)`、`Color.cyan`、`Color.red`）或字号字面量。

#### Scenario: 引用颜色
- **WHEN** 新视图需要主色 CTA 背景
- **THEN** 视图通过 `Theme.Color.accent` 获取色值，不允许在视图内直接构造 `Color`

### Requirement: 纸感色板 Token

设计系统 SHALL 提供以下颜色 token，色值精确对齐 C 设计稿：背景 `bg=#f4f2ec`、暖背景/次表面 `surface2=#efece5`、表面/卡片 `surface=#ffffff`、主边框 `border=#e4ddd0`、次边框 `border2=#d8d2c6`、正文 `fg=#1c1a17`、次级文字 `fg2=#5e5950`、静音文字 `muted=#9a9486`、强调 `accent=#d9482b`、强调浅底 `accentSoft=rgba(217,72,43,0.08)`、强调浅边 `accentSofter=rgba(217,72,43,0.18)`、成功 `ok=#3f9a5a`、错误 `danger=#d9482b`（与 accent 同源或更深红）。所有 colorset MUST 为 universal 单值（因强制浅色，无需明暗变体）。

#### Scenario: 卡片描边与背景
- **WHEN** 渲染任意 `cardStyle()` 卡片
- **THEN** 背景为 `surface`（白）、描边 1px `border`，与纸白页面 `bg` 形成层次

#### Scenario: 强调浅底着色
- **WHEN** 渲染 LIVE 横幅或选中态浅底
- **THEN** 背景使用 `accentSoft`（8% 朱砂红）、边框使用 `accentSofter`（18% 朱砂红）

### Requirement: 等宽数字字体回退

App SHALL 加载 JetBrains Mono 字体用于所有等宽数字展示（训练量、PR、计时器等）。若字体未注册（资源缺失或注入失败），`Theme.Font.mono` MUST 自动回退到 SwiftUI 系统 `.system(.monospaced)`，App MUST NOT 崩溃或显示 fallback 错误字形。

#### Scenario: 字体资源齐全
- **WHEN** App 启动并验证 `JetBrainsMono-Regular` 已注册
- **THEN** 所有 mono 字段以 JetBrains Mono 渲染

#### Scenario: 字体资源缺失
- **WHEN** Bundle 中缺少字体文件
- **THEN** `Theme.Font.mono(size:)` 返回 `.system(size:design:.monospaced)`，DEBUG 构建打印一次 OSLog warning，Release 构建静默回退

### Requirement: 字号语义层

`Theme.Font` SHALL 暴露与 C 设计稿一致的字号语义：Hero `32pt`、L1 `23pt`、L2 `16pt`、L3 `15pt`、L4 `13pt`、L5 `11pt`、计时器大字 `58pt`（mono）、标题帽 `10pt`（uppercase + tracking）。中文/标题用系统 PingFang SC（`.default` design），等宽数字用 JetBrains Mono（缺失回退系统 `.monospaced`）。

#### Scenario: 渲染屏幕大标题
- **WHEN** 视图需要屏幕级大标题
- **THEN** 使用 L1（23pt）或 Hero（32pt）语义字号，不写裸 `size:` 字面量

#### Scenario: 渲染计时器数字
- **WHEN** 休息计时弹窗渲染中心剩余时间
- **THEN** 使用 58pt mono tabular 数字

### Requirement: 纸感阴影修饰符

设计系统 SHALL 提供 `paperShadow(_ level:)` 修饰符，三级对齐设计稿：`sh-sm`=`shadow(rgba(28,26,23,.07), radius 4, y 1)`、`sh-md`=`shadow(rgba(28,26,23,.09), radius 8, y 4)`、`sh-lg`=`shadow(rgba(28,26,23,.12), radius 16, y 8)`，均附 `~0.5px` 描边近似。视图 MUST NOT 直接写 `.shadow(...)` 字面量参数，而 SHALL 通过 `paperShadow` 取得统一阴影。霓虹辉光质感 MUST NOT 出现在任何界面。

#### Scenario: 卡片纸感阴影
- **WHEN** 渲染 Hero 统计卡或 Sheet
- **THEN** 卡片用 `paperShadow(.sm)`、Sheet 用 `paperShadow(.lg)`，无任何彩色辉光

#### Scenario: 无霓虹辉光
- **WHEN** 渲染任意强调元素（CTA、PR 徽标、选中 chip）
- **THEN** 仅用纯色填充 + 纸感阴影，不出现 cyan/magenta 外发光

### Requirement: 禁用 List/Form 顶层容器

新视图（本 change 涉及的 9 屏及未来同风格视图）MUST NOT 使用 SwiftUI `List` 或 `Form` 作为顶层滚动容器。若因功能必要（如系统级 swipe-to-delete）必须使用，MUST 通过 `.scrollContentBackground(.hidden)` + `.background(Theme.Color.bg)` 隐藏 iOS 默认浅灰背景，并在视图代码注释中标注「必要的 List 用法」原因。

#### Scenario: 新增设置类视图
- **WHEN** 新增 `ProfileView` 或同类设置 / 列表视图
- **THEN** 顶层使用 `ScrollView { LazyVStack { ... } }`，分组用自绘 `eyebrow` + `cardStyle()` 容器；不出现 `List` / `Form`。

#### Scenario: 必须使用 List 的边缘场景
- **WHEN** 某视图必须使用 List（如需要原生 swipe action）
- **THEN** 视图 MUST 调 `.scrollContentBackground(.hidden).background(Theme.Color.bg)`，且文件注释解释为何无法用自绘 VStack。

### Requirement: 横向 Chip 选择器组件

设计系统 SHALL 提供 `HorizontalChipPicker<Item: Identifiable>` 组件：水平 `ScrollView` + `HStack(spacing: Theme.Spacing.sm)` + 每个 chip 高 32pt、横 padding 14pt、`Theme.Radius.pill` 圆角。选中态背景 `Theme.Color.accent` + 白色文字（无辉光）；未选中态背景 `Theme.Color.surface` + 1pt `Theme.Color.border` + `Theme.Color.fg2` 文字。

#### Scenario: 动作库部位筛选
- **WHEN** ExerciseLibraryView 渲染部位筛选 chips
- **THEN** 使用 `HorizontalChipPicker`，传入 `[全部, 胸, 背, 腿, 肩, 手臂, 核心]`，默认选中第 0 个，选中态为朱砂红实底白字。

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

设计系统中持续性 / 重复性动效（如 `repeatForever` 脉冲、`spring` 过渡）MUST 在 `@Environment(\.accessibilityReduceMotion)` 开启时退化为静态或淡入淡出。固定字号文本在易截断处 SHALL 配置 `minimumScaleFactor` 与合理 `lineLimit`，保证在系统放大字号（Dynamic Type）下不溢出、不破版。

#### Scenario: 减弱动态效果关闭重复动画
- **WHEN** 用户开启「减弱动态效果」并进入含 LIVE 脉冲的界面
- **THEN** 脉冲停止重复，呈现为静态样式

#### Scenario: 超大动态字号
- **WHEN** 用户将系统字号调至较大档位并浏览首页
- **THEN** 标题与副标文本按 `minimumScaleFactor` 适度缩放或截断，不超出卡片、不与相邻元素重叠

### Requirement: 统一圆形图标按钮

设计系统 SHALL 提供唯一的圆形图标按钮组件 `CircleIconButton`，作为所有 Header / 导航栏中「返回 / 更多操作 / 次级图标动作」的单一来源；视图代码 MUST NOT 在页面内本地复制等价实现（如自绘 `navCircle`、自绘 Menu 圆形 label）。

- 默认直径 SHALL 为 36pt（导航类圆钮与主操作钮 `CircleAddButton` 直径对齐）。
- 图标字号 SHALL 由组件按统一规则从直径推导，MUST NOT 在调用点硬编码图标字号；同一直径下所有圆钮的图标视觉重量一致。
- 外观为白底（`Theme.Color.surface`）+ 1pt `Theme.Color.border` 描边 + 圆形，按压走 `PressableButtonStyle`。
- SHALL 支持 `active` 高亮态（选中/展开时用 `Theme.Color.accent` 前景 + `Theme.Color.accentSoft` 底 + `Theme.Color.accentSofter` 描边）与 `rotated` 旋转态（如 `...` 展开时旋转 90°）。
- SHALL 提供动作菜单入口：以同一外观 label 触发 `PaperActionMenu`，确保「点击触发」与「弹出菜单」两类圆钮视觉完全一致；该动作菜单入口 MUST NOT 继续包装 SwiftUI `Menu`。

#### Scenario: 子页接入返回按钮

- **WHEN** 任一 push/sheet 子页需要返回按钮
- **THEN** 使用 `CircleIconButton(systemName: "chevron.left", ...)`，直径 36pt，图标字号由组件推导，外观为纸感白底圆形
- **AND** 不出现系统默认蓝色返回箭头

#### Scenario: 更多操作菜单圆钮

- **WHEN** Header 右侧需要 `...` 更多操作弹出菜单
- **THEN** 使用圆形图标按钮的动作菜单入口，其外观与点击触发版完全一致
- **AND** 菜单展开时圆钮进入 `active` + `rotated` 态
- **AND** 弹出的菜单为项目自绘 `PaperActionMenu`，不是 SwiftUI `Menu`

#### Scenario: 禁止本地复制实现

- **WHEN** 新增或修改任意页面的 Header 圆形按钮
- **THEN** 复用 `CircleIconButton` 或设计系统提供的同源动作菜单入口
- **AND** MUST NOT 在该页内重新声明等价的圆形按钮外观函数

### Requirement: 统一子页 Header 容器

设计系统 SHALL 提供子页（push/sheet 二级及以上页面）的 Header 容器 `PaperNavBar`（或等价的 `.paperToolbar()` 修饰符），封装以下职责，使各子页以单一接入点获得一致的导航栏：

- 隐藏系统默认返回按钮（`navigationBarBackButtonHidden(true)`）。
- 在隐藏系统返回按钮的同时，SHALL 恢复 iOS 左边缘侧滑返回手势（`interactivePopGestureRecognizer`），使所有 push 子页可通过侧滑返回上一页，行为与点击纸感圆形返回钮等价（标准 pop + 原生跟手转场）；该恢复 MUST 收口在容器内部，受益子页 MUST NOT 逐页自行处理。
- 侧滑返回的接管 MUST 做栈根页保护：仅当导航栈 `viewControllers.count > 1` 时允许手势开始，避免在 Tab 根页误触发 pop。
- 在 iOS 26+ 对工具栏按钮施加 `sharedBackgroundVisibility(.hidden)`，消除 Liquid Glass 自动圆形背景与纸感圆钮叠成的「双环」；低于 iOS 26 走等价无背景分支。
- 提供左（返回）/ 中（标题）/ 右（操作）三槽位；左、右槽位默认承载 `CircleIconButton`。
- 标题 SHALL 使用单一字体 token（取代既有系统 inline / `body(15,heavy)` / `display(30)` 等并存写法），居中、单行截断。

所有 push/sheet 子页的标题栏 MUST 经由该容器实现；MUST NOT 直接散用裸 `.toolbar { … }` + 手搓圆钮 + 逐 `ToolbarItem` 打 `sharedBackgroundVisibility` 补丁的旧写法。Tab 根页（训练 / 计划 / 动作 / Team / 我的）的自绘大标题范式不受此要求约束——其中「我的」(`ProfileView`) 作为 Tab 根页（无返回箭头）SHALL 归入自绘大标题范式（`display(36, heavy)`），不走 `.paperToolbar()`。侧滑返回手势仅作用于 push 出的子页，`fullScreenCover` / `sheet` 模态页不在此手势范围（其退出语义为下滑 dismiss）。

#### Scenario: 子页统一接入

- **WHEN** `WorkoutDetailView` / `PlanDetailView` / `TeamDetailView` / `ExerciseDetailView` / `TeamPlansView`（push/sheet 子页）渲染顶部标题栏
- **THEN** 均经由 `.paperToolbar()` 接入，标题字体一致、返回/操作钮均为 36pt 纸感圆钮
- **AND** 不再各自处理 `navigationBarBackButtonHidden` 与 iOS 26 双环补丁

#### Scenario: push 子页支持侧滑返回

- **WHEN** 用户在任一经 `.paperToolbar()` 接入的 push 子页（`PlanDetailView` / `PlanEditorView` / `WorkoutLoggingView` / `WorkoutDetailView` / `TeamDetailView` / `TeamPlansView` / `ExerciseDetailView`）从屏幕左边缘向右侧滑
- **THEN** 触发标准 pop 返回上一页，带原生跟手转场动画，效果与点击纸感圆形返回钮一致
- **AND** 该行为由 `.paperToolbar()` 容器统一提供，无需子页各自实现

#### Scenario: Tab 根页不被误触发返回

- **WHEN** 用户在导航栈根层（Tab 根页，`viewControllers.count == 1`）从左边缘侧滑
- **THEN** 不触发 pop，页面保持当前状态，不出现异常空白页或栈崩溃

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

### Requirement: 统一纸感动作菜单

设计系统 SHALL 提供统一纸感动作菜单组件，用于呈现轻量动作入口（例如顶部 `+`、Header `...`、分组 `...`）。本组件 MUST 使用项目自绘浮层，不得依赖 SwiftUI `Menu`、`.confirmationDialog` 或系统 action sheet 作为主要呈现方式。

菜单组件 MUST 支持：

- 由圆形 `+` 或圆形 `...` 触发。
- 菜单项标题、SF Symbol 图标、普通/危险角色、禁用态与动作回调。
- 展开时触发按钮进入 active 态；`...` 触发按钮可进入 rotated 态。
- 点菜单外区域关闭；选择菜单项后关闭菜单并执行对应动作。
- 根据触发按钮位置锚定弹出：默认右边缘对齐、显示在触发按钮下方，卡片顶部与触发圆钮底部保持 8pt 垂直间距，并在靠近屏幕边缘时保持菜单完整可见。
- 使用 `Theme.Color.surface`、`Theme.Color.border`、`Theme.Radius.lg`、`Theme.Font.*`、`paperShadow` 与 `PressableButtonStyle` 等现有纸感 token。
- 在系统开启 Reduce Motion 时禁用缩放/位移动效，退化为淡入淡出。

本 change 覆盖范围内的动作菜单入口 MUST 使用该组件，包括计划列表顶部 `+`、计划列表分组 `...`、计划详情 `...`、Team 列表顶部 `+`。二次确认弹窗和错误提示不属于本组件职责。

#### Scenario: 顶部添加菜单使用纸感组件

- **WHEN** 用户点击计划页或 Team 页右上角 `+`
- **THEN** 系统 SHALL 显示纸感动作菜单
- **AND** 菜单使用项目自绘白底卡片、描边、圆角和阴影
- **AND** 不显示 SwiftUI `Menu` 的系统弹层样式

#### Scenario: 分组更多菜单使用纸感组件

- **WHEN** 用户点击计划分组 header 右侧 `...`
- **THEN** 系统 SHALL 显示纸感动作菜单
- **AND** 菜单 SHALL 提供该分组可用操作，例如新建计划、调整计划顺序、重命名分组、删除分组
- **AND** 危险操作 SHALL 使用危险角色视觉或明确的危险文案

#### Scenario: 选择菜单项后关闭菜单

- **WHEN** 用户在纸感动作菜单中选择任一可用菜单项
- **THEN** 菜单 SHALL 先关闭
- **AND** 系统 SHALL 执行该菜单项对应动作
- **AND** 不得在后续 sheet、导航或确认弹窗出现时残留菜单浮层

#### Scenario: 点外关闭

- **WHEN** 纸感动作菜单已展开，用户点击菜单外的页面区域
- **THEN** 菜单 SHALL 关闭
- **AND** 不执行任何菜单项动作

#### Scenario: 边缘定位不溢出

- **WHEN** 触发按钮位于屏幕右上角或靠近安全区域边缘
- **THEN** 菜单 SHALL 默认与触发按钮右边缘对齐
- **AND** 菜单顶部与触发圆钮底部 SHALL 保持 8pt 垂直间距
- **AND** 菜单 SHALL 自动避让屏幕边缘
- **AND** 菜单内容 SHALL 完整可见，不被屏幕裁切

#### Scenario: 减弱动态效果

- **WHEN** 系统「减弱动态效果」开启，用户展开或关闭纸感动作菜单
- **THEN** 菜单 SHALL 使用淡入淡出过渡
- **AND** 不执行缩放或位移动效

