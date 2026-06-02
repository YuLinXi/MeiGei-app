## Context

训练首页 `WorkoutListView`（`ios/MeiGei/MeiGei/Workout/WorkoutViews.swift`）是 App 最高频入口，视觉与核心功能已成熟。本次为一轮**纯 iOS 客户端 UI 层**的保守微调：补手感、补入口、补无障碍，不触碰后端、数据模型与同步逻辑，因此 Day-1 数据铁律（身份三层 / 幂等键 / 同步字段 / 软删除）在本 change 中**不涉及新增数据流**——唯一关联的删除路径沿用既有 `markDeleted()` 软删墓碑机制，不改动。

现状约束：
- 全 App 按钮统一 `.buttonStyle(.plain)`，无按压反馈；无 `ButtonStyle` 可复用。
- haptic 触感裸调用散落在 `RestTimerSheet.swift:29,53`，无统一封装。
- 工具栏右上角为占位「搜索」图标 + 「加号」菜单（`WorkoutViews.swift:79-91`），搜索无逻辑；加号菜单与底部悬浮 CTA 在「开始训练」上职责重叠。
- 「进行中」计划判定逻辑已存在于 `PlanViews.swift:20-26`（`activePlan`），但首页无感知。
- 全 App 无任何 `accessibilityLabel` / `accessibilityReduceMotion` / Dynamic Type 适配。

## Goals / Non-Goals

**Goals:**
- 首页关键交互（开始 / 继续 / 删除 / 结束）有统一触感与按压微反馈，且尊重「减弱动态效果」。
- 首页工具栏右上角清空（移除占位搜索与加号菜单），开始训练收敛为唯一的底部悬浮 CTA。
- 「进行中」计划在该 CTA 上以智能单键上浮，减少空白训练的误用与入口重叠。
- 首页对 VoiceOver / Dynamic Type 用户基本可用。
- 全程复用既有 `Theme.*` token 与 Modifier，不引入新色、不换字体、不改布局结构。

**Non-Goals:**
- 不做首页搜索（本轮直接移除占位入口，不实现任何检索）。
- 不在首页保留多计划选择入口（交由「计划」tab）。
- 不做 Team「今日打卡」跨 tab 概览（需新拉取 + 新视图，体量超本轮）。
- 不做 `Theme+Font` 全局 `relativeTo:` Dynamic Type 根因改造（波及全 App，独立 change）。
- 不新增任何数据展示卡（PR 计数 / 周对比 / streak / 肌群分布）。
- 不改后端、数据模型、同步协议。

## Decisions

### D1. 触感统一为 `Theme.Haptics`，而非继续裸调用
在 `DesignSystem/Haptics.swift` 新增 `extension Theme { enum Haptics }`，暴露 `impact(_:)` / `selection()` / `notification(_:)` 静态方法，内部包 `UIImpactFeedbackGenerator` / `UISelectionFeedbackGenerator` / `UINotificationFeedbackGenerator`。
- **为何**：触感语义（轻点 / 选择 / 成功失败）需跨视图一致；集中封装便于后续统一调参或全局开关。
- **备选**：保持裸调用——否决，散落难维护且语义不统一。
- 顺手把 `RestTimerSheet.swift:29,53` 两处迁到 `Theme.Haptics`。

### D2. 按压反馈用自定义 `PressableButtonStyle`，而非逐处手写
在 `DesignSystem/Modifiers.swift` 新增 `struct PressableButtonStyle: ButtonStyle`：`isPressed` 时 `scaleEffect(0.97)` + `opacity(0.92)`，`animation(.easeOut(duration: 0.12), value: isPressed)`。
- **为何**：scale 收敛在 0.97 不引发布局位移（符合 ui-ux-pro-max「stable hover/press」准则）；120ms 落在 150–300ms 微交互区间内偏快端，符合「跟手」预期。
- **reduceMotion**：样式内读 `@Environment(\.accessibilityReduceMotion)`，开启时退化为仅 opacity、无 scale。
- 首页 `startCTA` / `continueBanner` / `SwipeToDeleteCard` 内容点击从 `.plain` 换为本样式；PlanViews/ExerciseViews 暂不动，控制范围。

### D3. 移除工具栏右上角入口，开始训练单一收敛到底部 CTA
删除 `WorkoutViews.swift` 工具栏 `topBarTrailing` 整组（占位搜索 `Image` + 加号 `Menu`），右上角不再有任何控件；左上角日历入口保留。开始训练只剩底部悬浮 CTA 一条路径。
- **为何**：占位搜索无价值，加号菜单与底部 CTA 在「开始训练」上职责重叠；移除后入口唯一、心智最简，契合「严肃工具」克制取向。
- **备选**：落地搜索 / 保留加号——按用户明确要求否决，二者均移除。
- **代价**：失去首页内「多计划快速选择」与「显式空白训练」两个入口 → 多计划选择改由「计划」tab 承载；空白训练由无计划态的 CTA 兜底（见 D4）。`startBlank()` / `start(from:)` 两个动作函数保留，仅调用入口从菜单改为 CTA。

### D4. 底部 CTA 为「智能单键」，判定逻辑复用不重写
把 `PlanViews.swift:20-26` 的 `activePlan` 判定（近 14 天有关联 workout 的计划，否则最近更新的计划）抽为可复用入口（`WorkoutPlan` 静态方法或共享计算），首页与计划页共用同一份判定。CTA 行为：无进行中会话时，存在 `activePlan` → 文案「从「\(name)」开始」、走 `start(from:)`；无任何计划 → 文案「开始今日训练 / 开始第 1 次训练」、走 `startBlank()`。单点击、无长按、无备选菜单。
- **为何**：避免两处逻辑漂移导致首页与计划页「进行中」不一致；单键无分支，决策成本最低。
- **备选**：智能单键 + 长按备选（空白/选其它计划）——否决，用户选择最简单键，不引入隐藏手势。
- **既有约束保留**：存在进行中会话时，CTA 之外的「继续训练」横幅与单一活跃会话守卫（`beginSession` 的继续/丢弃冲突弹窗）行为不变。

### D5. 无障碍按「能读 + 不破版 + 可降级」三条做，不追求满分
- VoiceOver：图标-only 按钮补 `accessibilityLabel`；`continueBanner` / `recentRow` 用 `.accessibilityElement(children: .combine)` 合成语义整句；三宫格 `accessibilityValue`；`SwipeToDeleteCard` 补 `accessibilityAction(named: "删除")`（左滑手势对 VoiceOver 不可达）。
- reduceMotion：LIVE 红点 `repeatForever` 脉冲、`restFAB` neonGlow 持续光晕、`.spring()` 过渡统一在开关开启时退化为静态/淡入淡出，与 D2 共用同一 Environment。
- Dynamic Type：固定 size 自定义字体本轮**不**改为 `relativeTo:`，仅对易截断文本加 `minimumScaleFactor(0.85)` + `lineLimit`，保证大字号不破版。

## Risks / Trade-offs

- **[scale 按压在嵌套手势中抖动]**：`SwipeToDeleteCard` 内容同时有拖动手势与按压样式 → 缓解：按压样式只作用于点击触发的 Button，拖动走 `highPriorityGesture`，二者互不接管；实测确认无冲突。
- **[Dynamic Type 仅做防截断，治标不治本]**：固定字号在超大动态字号下仍偏小 → 缓解：明确列为 Non-goal 与后续 change，本轮先保证不破版、不溢出。
- **[`activePlan` 逻辑抽取改动 PlanViews]**：触及计划页 → 缓解：仅做等价抽取、行为不变，编译 + 视觉回归计划页确认一致。
- **[haptic 仅真机可验]**：模拟器无触感 → 缓解：验证步骤标注真机确认，模拟器只验逻辑与编译。
