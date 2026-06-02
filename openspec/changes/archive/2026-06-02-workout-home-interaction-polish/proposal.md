## Why

训练首页（`WorkoutListView`）视觉与功能已成熟，但在「手感、入口、无障碍」三处有明确短板：所有按钮用 `.buttonStyle(.plain)` 点按零反馈、haptic 触感散落在 `RestTimerSheet` 裸调用、工具栏搜索是占位未实现、「进行中」计划进度埋在「计划」tab 首页无感知；且全 App 尚无任何 `accessibilityLabel` / `reduceMotion` / Dynamic Type 适配，对辅助功能用户不可用。本次在**不改动布局结构、不引入新色、不换字体、不新增数据卡**的前提下做一轮保守微调，补齐这些细节。

## What Changes

- **交互打磨**
  - 新增统一触感封装 `Theme.Haptics`（impact/selection/notification），收敛 `RestTimerSheet` 现有裸 `UI*FeedbackGenerator` 调用；接入首页开始/继续/删除/结束等关键时刻。
  - 新增可复用 `PressableButtonStyle`（按压 `scaleEffect(0.97)` + 微降透明度，120ms），尊重 reduceMotion；接入首页 CTA / 继续横幅 / 最近训练行。
  - `SwipeToDeleteCard` 左滑删除打磨：越过显露阈值触发一次 selection 触感、显露/收回回弹对称、补 `accessibilityAction` 让 VoiceOver 无需手势即可删除。
- **信息架构 / 入口（开始入口收敛）**
  - 移除首页工具栏右上角的占位「搜索」图标与「加号」菜单（含「空白训练」与「从某计划开始」两类项），右上角清空；左上角「日历」入口保留。
  - 开始训练收敛为底部悬浮 CTA 智能单键：复用「计划」tab 既有 `activePlan` 判定（近 14 天有关联 workout 的计划，否则取最近更新计划），存在「进行中」计划时 CTA 文案与动作上下文化为「从「计划名」开始」并走 `start(from:)`，否则为空白训练；CTA 不提供任何备选菜单。多计划选择改由「计划」tab 承载。
- **视觉细节 / 无障碍**
  - 补 VoiceOver：图标-only 按钮加 `accessibilityLabel`、继续横幅/最近行 `combine` 成单元素语义整句、三宫格 `accessibilityValue`。
  - reduceMotion 退化：LIVE 红点脉冲、`restFAB` 持续光晕、各 `.spring()` 过渡在开启「减弱动态效果」时退化为静态/淡入淡出。
  - Dynamic Type 防截断：首页易截断文本加 `minimumScaleFactor` + 合理 `lineLimit`，大字号下不破版。

## Capabilities

### New Capabilities

（无新增 capability，均落在既有 spec 的 delta 中。）

### Modified Capabilities

- `design-system`: 新增「触感反馈封装」「按压交互样式」「reduceMotion 与 Dynamic Type 基线」三条 requirement —— 触感与动效降级是设计系统层的横切约定。
- `workout-tracking`: 移除首页工具栏「搜索」与「加号」入口，新增「首页开始入口收敛为智能单键 CTA」requirement；修改「删除训练记录」「进行中会话继续横幅」补触感与无障碍。

## Impact

- 主要改动文件：`ios/MeiGei/MeiGei/Workout/WorkoutViews.swift`（主体）、`ios/MeiGei/MeiGei/DesignSystem/Haptics.swift`（新建）、`ios/MeiGei/MeiGei/DesignSystem/Modifiers.swift`（新增 `PressableButtonStyle`）、`ios/MeiGei/MeiGei/Workout/PlanViews.swift`（抽取复用 `activePlan` 判定）、`ios/MeiGei/MeiGei/Workout/RestTimerSheet.swift`（收敛裸 haptic）。
- 不改后端、不改数据模型、不引入新依赖；纯 iOS 客户端 UI 层。
- 不引入新色 / 不换字体 / 不改布局结构；移除工具栏右上角入口后不新增任何网络调用或 `@Query`。

## Non-goals

- **不做** Team「今日打卡」跨 tab 概览联动（需新 `TeamService` 拉取 + 新视图，体量超出本轮保守微调）。
- **不做** `Theme+Font` 的全局 `relativeTo:` Dynamic Type 根因改造（波及全 App 所有页面，需整体视觉回归，留作后续独立 change）。
- **不新增**任何数据展示卡（PR 计数、周对比、streak、肌群分布等"功能增强"方向本轮明确排除）。
- **不改动**首页整体布局结构、配色与字体。
