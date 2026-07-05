## Why

当前 Team 历史训练的月份选择只暴露已加载月份，导致已有历史月份（例如 6 月）无法被发现；训练首页缺少一眼可见的一周完成节奏；动作库右侧快速筛选区域靠近动作卡片，快速滑动时容易误触进入详情。这个 change 统一收敛这些高频浏览路径的体验问题，让历史可追溯、首页更有训练节奏感、动作库长列表导航更稳定。

## What Changes

- Team 历史训练月份选择改为展示从 Team 创建月到当前月的完整月份范围，未加载月份也可被选择；选择后按月加载对应 Team checkin 历史，不能把未加载月份误表达为“没有训练”。
- 训练首页增加一周训练勾选视图，基于本地已完成训练按周一到周日派生完成状态，配合当前本周训练统计展示，不新增手动打卡或目标系统。
- 动作库右侧快速定位改成类似 iOS 通讯录的独立索引触控体验，支持按住上下滑动快速切换筛选/定位，并减少与动作卡片点击区域的重叠误触。
- 保持现有纸感视觉体系、Theme token、离线优先训练统计、Team 服务端权威数据边界不变。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `team-ui`: 明确 Team 历史训练月份档案必须覆盖完整可选月份范围，并区分未加载、空月份和有训练月份。
- `workout-tracking`: 首页新增一周训练勾选视图，状态来自本地已完成训练记录的派生快照。
- `exercise-library`: 动作库右侧快速定位区改为独立、可拖拽、低误触的索引交互。

## Non-goals

- 不新增 Team 历史 checkin 的本地 SwiftData 缓存；Team 历史仍按需从服务端拉取。
- 不新增手动打卡、补签、连续训练 streak、周目标配置或社交挑战功能。
- 不改动 Workout/WorkoutSet 同步协议，不把首页周勾选状态作为同步实体上传。
- 不重做动作库信息架构、动作分类、搜索规则、器械筛选数据源或肌群缩略图资产。
- 不引入新的后端写接口、推送机制、第三方 UI 依赖或新设计体系。

## Impact

- iOS Team：`TeamCheckinHistoryView`、`TeamCheckinHistoryModels`、共用月份档案 sheet 的展示语义可能需要调整。
- iOS Workout：首页 `WorkoutListView` 与 `WorkoutHistoryStore.HomeWorkoutSnapshot` 需要增加本周每日完成状态的派生数据。
- iOS Exercise Library：`ExerciseLibraryContentView` 右侧快速筛选/索引触控区域需要优化，避免与动作行点击抢手势。
- 后端：预计不需要 schema 迁移或新写接口；若实施中发现 Team 创建月不足以覆盖历史月份，再评估只读月份摘要接口，但本 change 默认优先客户端范围修复。
