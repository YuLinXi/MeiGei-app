## Why

iOS 各页面的顶部标题栏（Header / 导航栏）目前缺乏统一规范，散落出三套范式与三套圆形按钮实现，视觉与交互不一致：同一个「圆形图标钮」在 `DesignSystem` 默认 38pt、调用点全覆写成 32pt、添加钮又是 36pt；`TeamDetailView.navCircle`、`PlanDetailView.menuButton` 各自复制了一份外观；图标字号有的按 `size×0.4` 算、有的硬编码 15；「我的 / 动作详情 / TeamPlans」还在用系统蓝色返回箭头，和其它页的纸感圆钮割裂。规范缺位导致每加一个页面都要重新「手搓」一遍 Header，且偏差越积越大，趁页面数量还可控时收敛成本最低。

## What Changes

- **收敛圆形图标钮为单一组件**：把 `TeamDetailView.navCircle`、`PlanDetailView.menuButton` 两处本地实现并入 `DesignSystem` 的 `CircleIconButton`，补齐 `active`/`rotated` 态与 Menu 版 label，删除重复代码。
- **统一圆钮直径为 36pt**：导航类圆钮（返回 / ⋯）从 32 放大到 36，与主操作钮 `CircleAddButton`（36）对齐；图标字号改为按统一规则给定（不再 `size×0.4` 与硬编码 15 并存）。
- **新增子页 Header 容器 `PaperNavBar` / `.paperToolbar()`**：封装 `navigationBarBackButtonHidden(true)` + iOS 26 `sharedBackgroundVisibility(.hidden)`（消除 Liquid Glass 双环）+ 左返回 / 中标题 / 右操作三槽位，子页一行接入。
- **B3 页面改纸感圆形返回钮**：`ProfileView`、`ExerciseDetailView`、`TeamPlansView` 从系统蓝色返回箭头改用纸感圆形 `chevron.left`。
- **统一子页标题字体 token**：子页 inline 标题统一到单一字体 token（取代系统 inline / `body(15,heavy)` / `display(30)` 三种飘移）。
- 保留 **Tab 根页自绘大标题范式**（`display(36, heavy)` + 右上单按钮）不变——它本身已自洽，仅确保「我的」页归入同一范式约定。

## Capabilities

### New Capabilities
<!-- 无新增 capability，本次为既有 design-system 的需求扩展 -->

### Modified Capabilities
- `design-system`: 新增「统一页面 Header / 导航栏」与「圆形图标按钮规范」两条需求——定义圆钮单一组件契约（直径 36、图标字号规则、active/rotated/Menu 变体）、子页 Header 容器 `PaperNavBar`、以及「所有 push/sheet 子页 MUST 经统一容器、禁止裸用系统返回箭头」的一致性约束。

## Impact

- **DesignSystem**：`Components.swift`（改 `CircleIconButton`、新增 `PaperNavBar`/`.paperToolbar()`）。
- **页面接入**：`Workout/WorkoutDetailView.swift`、`Workout/PlanViews.swift`、`Workout/WorkoutViews.swift`、`Team/TeamViews.swift`（删 `navCircle`）、`Profile/ProfileView.swift`、`Workout/ExerciseViews.swift`、`MainTabView.swift`（如需调整子页标题字体约定）。
- **纯 iOS UI 规范统一**：不涉及后端、数据模型、网络契约；无数据迁移；非破坏性（仅视觉与组件 API 收敛）。
- **风险**：iOS 26 `sharedBackgroundVisibility` 需保持可用版本分支；改动集中在视图层，靠 `xcodebuild` 编译验证 + 真机目测各页 Header 一致性。

## Non-goals

- **不重做 Tab 根页大标题范式**：`display(36, heavy)` 自绘大标题保留，本次不改其字号/布局。
- **不改 Tab Bar 外观**：底部 Tab 的纸感配置（`MainTabView` 的 `UITabBarAppearance`）不动。
- **不引入通用「页面脚手架」抽象**：只统一 Header，不顺带封装内容区滚动 / 底栏 / safeArea 等其它布局。
- **不改任何 Header 触发的业务逻辑**：返回 / ⋯ 菜单项、删除确认弹窗等行为保持原样，仅替换外观与组件来源。
- **不做深色模式额外适配**：沿用现有强制浅色纸感外观，不在本次扩展配色。
