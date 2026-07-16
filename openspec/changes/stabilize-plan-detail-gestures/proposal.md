## Why

计划详情页的动作卡同时挂载自定义横向拖拽、纵向滚动与系统侧滑返回手势；当触点落在动作卡区域时，多个识别器竞争会导致上下滚动和右滑返回频繁断触。需要在保留动作删除能力的前提下，恢复该页面的原生滚动与返回手势稳定性。

## What Changes

- 计划详情动作区改用原生 `List` 行承载，继续保持现有纸感卡片、标题、统计、模式说明、添加动作和底部 CTA 版式。
- 动作删除改用原生 trailing `swipeActions`，保留左滑删除并禁止全滑直接删除。
- 删除确认改用现有 `paperConfirmDialog`，移除计划详情对自定义滑动协调器和锚点式全屏确认层的依赖。
- 明确计划详情的动作卡区域必须能连续纵向滚动，并能从屏幕左边缘连续右滑返回。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `workout-tracking`: 调整计划详情动作列表的交互承载方式，并补充滚动、侧滑返回和动作删除手势互不干扰的行为要求。

## Impact

- 影响 iOS `PlanDetailView` 的列表和删除确认交互。
- 不改变训练计划数据模型、同步协议、公开 API、导航容器或其他页面共用的 `SwipeDeleteList`。
- 不新增依赖，不涉及后端与数据库迁移。

## Non-goals

- 不重构全局 `paperToolbar` 或 `interactivePopGestureRecognizer` 接管逻辑。
- 不替换首页等其他页面正在使用的 `SwipeDeleteList`。
- 不改变计划动作排序、编辑、处方展示、开始训练或复制计划的业务行为。
