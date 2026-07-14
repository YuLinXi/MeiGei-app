## Context

`PlanDetailView` 当前以外层 `ScrollView` 承载动作卡，并在每张卡上通过 `SwipeDeleteList` 附加 `DragGesture`。该手势只有在开始回调后才判断横纵方向，因此触点落在动作卡时，它会先与 `ScrollView` 的纵向 pan 及 `paperToolbar` 恢复的系统边缘返回手势共同参与识别，造成滚动或返回转场中途失去触摸。

iOS 17.4 已提供 `List` 与 `swipeActions` 的原生组合，可让系统统一仲裁行侧滑、列表滚动和导航返回。本改动仅涉及客户端视图交互；训练计划仍沿用现有 `WorkoutPlan`、稳定 `itemId`、软删除和离线同步字段，不改变任何数据模型或同步规则。

## Goals / Non-Goals

**Goals:**

- 让用户从动作卡区域开始拖动时也能连续上下滚动。
- 让用户从屏幕左边缘、包含动作卡的高度开始右滑时也能连续返回上一页。
- 保留动作卡点击编辑和左滑删除，并继续要求二次确认。
- 保持计划详情现有纸感视觉层级与业务行为。

**Non-Goals:**

- 不修改全局 `paperToolbar`、`SwipeBackGestureDelegate` 或导航栈行为。
- 不重构其他页面复用的 `SwipeDeleteList`。
- 不改变动作排序、处方、计划模式、复制或开始训练逻辑。
- 不新增依赖、API、数据库字段或迁移。

## Decisions

### 使用原生 `List` 与 `swipeActions`

计划详情的全部可滚动内容由一个 plain `List` 承载，每个计划动作使用稳定 `itemId` 作为行身份。动作行继续渲染现有 `planItemRow` 卡片，通过透明行背景、隐藏分隔线和定制 row insets 保持当前纸感样式。

删除入口使用 trailing `swipeActions`，并设置 `allowsFullSwipe: false`。这样纵向滚动、行横滑和系统边缘返回均由 UIKit/SwiftUI 原生手势体系仲裁，不再由页面级 `DragGesture` 抢先参与。

备选方案是继续调高自定义 DragGesture 阈值或引入 UIKit 方向代理。前者仍无法在手势开始前退出竞争，后者在 iOS 17.4 需要额外桥接且会扩大维护面，因此不采用。

### 删除确认复用 `paperConfirmDialog`

用户点原生删除 action 后，仅记录待删除 `PlanItem`，再由现有 `paperConfirmDialog` 展示二次确认。删除不再依赖动作卡的屏幕坐标，也不再使用透明 `fullScreenCover`。

备选方案是保留锚点式确认层，但原生 action 不需要卡片锚点，继续维护几何信息只会留下无用状态和额外覆盖层，因此不采用。

### 变更严格限定在计划详情

共享 `SwipeDeleteList` 与全局侧滑返回实现保持原样。问题最稳定地出现在计划详情动作卡组合上，局部替换即可解决，不扩大到未报告故障的页面。

## Risks / Trade-offs

- [原生 `List` 默认间距或背景与原页面不同] → 显式使用 plain 样式、透明背景、隐藏分隔线与固定 insets，并通过 Simulator 人工检查。
- [原生 swipe action 外观与自绘删除按钮略有差异] → 采用主题危险色和明确的垃圾桶图标；优先保证平台手势稳定性。
- [系统行为仍可能受全局返回代理影响] → 本次移除最直接的行级竞争源，并覆盖动作卡区域的纵向滚动、边缘返回和左滑删除人工回归；若其他页面仍复现，再单独调整全局代理。

## Migration Plan

随 iOS 客户端正常发布，无数据迁移和部署顺序要求。若需回滚，只需恢复 `PlanDetailView` 原有 `ScrollView` 与 `SwipeDeleteList` 组合，不影响已保存计划数据。

## Open Questions

无。
