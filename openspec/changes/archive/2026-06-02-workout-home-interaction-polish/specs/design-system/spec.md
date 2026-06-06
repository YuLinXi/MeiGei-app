## ADDED Requirements

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
