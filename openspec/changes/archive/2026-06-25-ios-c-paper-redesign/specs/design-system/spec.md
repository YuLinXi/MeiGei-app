## MODIFIED Requirements

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

### Requirement: 横向 Chip 选择器组件

设计系统 SHALL 提供 `HorizontalChipPicker<Item: Identifiable>` 组件：水平 `ScrollView` + `HStack(spacing: Theme.Spacing.sm)` + 每个 chip 高 32pt、横 padding 14pt、`Theme.Radius.pill` 圆角。选中态背景 `Theme.Color.accent` + 白色文字（无辉光）；未选中态背景 `Theme.Color.surface` + 1pt `Theme.Color.border` + `Theme.Color.fg2` 文字。

#### Scenario: 动作库部位筛选
- **WHEN** ExerciseLibraryView 渲染部位筛选 chips
- **THEN** 使用 `HorizontalChipPicker`，传入 `[全部, 胸, 背, 腿, 肩, 手臂, 核心]`，默认选中第 0 个，选中态为朱砂红实底白字。

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

## RENAMED Requirements

- FROM: `### Requirement: 强制深色外观`
- TO: `### Requirement: 强制浅色外观`

## REMOVED Requirements

### Requirement: 品红色专用语义
**Reason**: 纸感极简设计稿强调色收敛为朱砂红单色，PR 与普通 CTA 共用 `Theme.Color.accent`，不再保留品红专用语义；`accentMagenta`/`accentCyan` token 在本 change 收尾删除并统一为 `accent`。
**Migration**: 原使用 `accentMagenta` 的 PR 元素改用 `Theme.Color.accent`；原使用 `accentCyan` 的通用强调亦改用 `Theme.Color.accent`。视图迁移期可暂以别名指向同一朱砂红 colorset，迁移完成后删除别名。
