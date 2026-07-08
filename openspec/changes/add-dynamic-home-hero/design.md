## Context

训练首页目前由 `WorkoutListView` 渲染，顶部 `heroSection` 只根据本周训练次数在「准备好了吗？」和「本周训练量」之间切换。数据来源已经收敛到 `WorkoutHistoryStore.home` 的轻量快照，避免首页直接遍历完整 `Workout -> Exercise -> Set` 聚合树。

本次变更只升级首页顶部展示层：用户提供三张本地图片作为 Hero 背景，左侧叠加状态文案，右侧保留图片主体。底部固定「开始训练」CTA、进行中训练全局浮层、同步模型和后端契约保持不变。

## Goals / Non-Goals

**Goals:**

- 用三张本地图片表达首页训练状态：待完成 / 今日完成 / 连续打卡。
- 在 Hero 左侧显示简短中文状态文案，避免依赖图片内嵌文字传达关键信息。
- 状态判断只使用本地训练记录和现有 active session 查询。
- 保持首页渲染轻量，不在 SwiftUI `body` 中扫描完整历史聚合树。
- 保持 Dynamic Type、VoiceOver 和减弱动态效果下的基本可用性。

**Non-Goals:**

- 不新增后端、同步、数据库、UserDefaults 或远程配置字段。
- 不改变首页底部 CTA 的固定文案和无计划训练创建逻辑。
- 不把顶部 Hero 设计成可点击按钮。
- 不新增图片下载、缓存、A/B 实验、目标配置或动画框架。

## Decisions

### D1. Hero 状态由本地快照派生，不持久化

新增轻量的首页派生字段（如今日完成次数、连续训练天数）时，优先放在 `HomeWorkoutSnapshot`，由 `WorkoutHistoryStore` 构建快照时一次性计算。视图层只消费快照，不再为 Hero 额外读取进行中训练状态。

选择原因：符合既有首页性能设计，不把派生统计写入同步真相源，也不让 `WorkoutListView.body` 直接扫描历史。

备选方案是在 `WorkoutListView` 内从 `weekWorkouts` 推导全部状态。该方案改动更小，但 `weekWorkouts` 只覆盖本周，无法可靠计算跨周连续训练天数。

### D2. 状态优先级固定为 streak > today done > pending

首页 Hero 状态按以下优先级选择：

1. 今天已有完成训练且连续训练天数 >= 3：`streak`。
2. 今天已有完成训练：`doneToday`。
3. 其它情况：`pendingToday`。

选择原因：顶部 Hero 只表达当天记录状态和连续训练反馈；进行中训练已经由全局训练浮层承载，继续在 Hero 里显示下一组或计时会形成重复信息。

### D3. 图片只作为装饰背景，语义由 SwiftUI 文案提供

三张图片导入 Asset Catalog，建议命名：

- `homeHeroStreak`
- `homeHeroPending`
- `homeHeroDone`

Hero 使用统一高度和圆角裁切。图片通过 `resizable().scaledToFill()` 填充，左侧文案覆盖在图片预留空白区。左侧标题字号控制在当前首页标题以下，避免压住图片主体；图片设置为无障碍隐藏，VoiceOver 读取状态标题、副标题和说明。

选择原因：图片原始尺寸比例不同，统一裁切能避免首页高度跳动；图片内嵌文字不适合承担无障碍语义。

### D4. 不复用卡片样式包裹 Hero

Hero 使用图片自身的圆角和轻量边框/阴影，不再套现有 `cardStyle()` 白底卡片。其它首页模块保持原样。

选择原因：图片已经包含完整背景和主体，外面再套白底卡片会显得重复，也会压缩视觉空间。

## Risks / Trade-offs

- [Risk] 原图自带圆角且无 alpha，边角可能有暗色像素。  
  → Mitigation：SwiftUI 外层统一圆角裁切；如真机仍露出暗角，再单独裁成干净矩形资产。

- [Risk] 大字号下左侧文案可能挤压图片主体。  
  → Mitigation：文案限制为标题 1 行、副标题 1 行、说明 2 行，并设置 `minimumScaleFactor`；图片语义不依赖内嵌文字。

- [Risk] 连续训练天数跨周计算需要完整完成日序列。  
  → Mitigation：在 `WorkoutHistoryStore` 构建快照时从已完成训练日期集合倒推，仍属于本地派生统计，不新增持久化。

- [Risk] 顶部 Hero 看起来像可点击入口。  
  → Mitigation：不添加按钮 trait、点击手势或 CTA 文案，真正开始入口仍在底部固定 CTA。

## Migration Plan

1. 将三张图片复制到 Asset Catalog。
2. 扩展首页快照的轻量派生状态。
3. 替换 `WorkoutListView.heroSection` 为动态图片 Hero。
4. 编译 iOS target 验证。

回滚策略：删除新增图片资产和 Hero 视图改动，恢复原 `heroSection` 文本卡片；无数据迁移需要回滚。

## Open Questions

- 三张图片是否需要后续统一导出为相同画幅和无内嵌圆角的版本。当前实现先用 SwiftUI 裁切兜底。
