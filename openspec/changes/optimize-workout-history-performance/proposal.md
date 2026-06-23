## Why

本地导入 500+ 条历史训练后，首页、动作库、计划详情、动作详情等页面出现明显卡顿。当前模拟器库实测规模为 439 条 `Workout`、1936 条 `WorkoutExercise`、8188 条 `WorkoutSet`，其中首页实际只展示本周摘要与最近 8 条，但 `WorkoutListView` 仍订阅全部未删除训练，并在 SwiftUI computed property 中多处实时遍历完整聚合树。

这不是“历史数据太多”的问题，而是**展示层把原始训练聚合树当作实时统计输入**。OpenSpec MVP 规定“统计数据 MUST 可由原始记录重算，SHOULD 避免持久化冗余统计结果”，这个原则仍然正确；需要修正的是实现边界：**可重算不等于每次 `body` 渲染时重算**。

同类 App 的公开行为也支持这个方向：

- Strong / Hevy / Fitbod 都把大历史、导入导出、PR、图表、训练推荐作为正常场景，而不是异常路径。
- Hevy 的统计按 last 7 days / 30 days / 3 months / year / all time 等范围切片，Monthly Report 只总结上个月，避免首页无界计算。
- Fitbod 的动作历史与推荐使用训练历史作为输入，但以“能力/趋势/恢复状态”等派生信号服务后续体验。
- Strong 公开更新日志中曾修复“大训练历史下 PR 计算慢、处理大量 workouts 导致 slowdown/后台终止、large workout histories 用户冻结”等问题，说明此类性能问题在同类训练 App 中真实存在。

## What Changes

- **引入历史性能边界**：UI 根页面不得直接订阅完整 `Workout` 聚合树并在 `body` / computed property 中反复扫描 `WorkoutExercise` / `WorkoutSet`。
- **首页改为窄输入**：本周统计、最近 8 条、active session、active plan 分别用窄查询或派生快照提供；首页不再持有全量 workouts。
- **收口派生统计**：新增本地 `WorkoutHistoryProjection`（命名可调整）作为可重建派生层，一次扫描原始记录后产出纯值快照，供首页、动作库、动作详情、计划详情、Profile 复用。
- **计划自适应预填查表化**：从“每个计划动作扫全量历史”改为“先构建 latest lookup，再按 `planItemId/historyKey` O(1) 取值”。
- **动作历史按需钻取**：动作库列表只消费 PR 摘要，动作详情按 exercise key 读取历史序列，不再订阅全量 `Workout`。
- **启动与同步减负**：一次性迁移加执行标记；同步只 fetch pending 或增量需要的数据，避免回前台触发全量对象扫描。
- **验收加入数据规模基线**：用当前 439/1936/8188 数据集，以及扩展到 1000/5000 workouts 的压测数据集验收页面响应。

## Capabilities

### New Capabilities
<!-- 无新增 capability -->

### Modified Capabilities
- `workout-tracking`: 修改“训练历史与 PR 识别”相关 requirement，明确统计可重算但 UI MUST 使用窄查询、缓存快照或可重建派生索引，不得在常规页面渲染路径上反复全量扫描历史聚合树。

## Impact

- **iOS 数据访问**：`WorkoutListView`、`ExerciseLibraryContentView`、`ExerciseDetailView`、`PlanListView`、`PlanDetailView`、`WorkoutDetailView`、`ProfileView` 的 `@Query<Workout>` 边界需要收窄或移出视图层。
- **iOS 派生层**：新增 `WorkoutHistoryProjection` / `WorkoutHistoryStore` 一类 `@Observable` 服务，维护纯值快照，快照可由 SwiftData 原始记录完整重建。
- **iOS 统计函数**：`PRStats`、`WorkoutWeeklyStats`、`PlanPrefill` / `PlanPrescriptionPreview` 需支持从快照或预建 lookup 取值。
- **iOS 启动**：`ExerciseHistoryMerge.run` 需加一次性标记，避免每次启动 fetch 全部 `WorkoutExercise`。
- **iOS 同步**：`SyncEngine.syncWorkouts()` 需避免每次同步 `FetchDescriptor<Workout>()` 全量 fetch；pending push 和 pull upsert 分别采用窄查询/lookup。
- **数据库索引**：评估 SwiftData/Core Data 底层可用索引能力；如最低系统版本不支持 `#Index`，则先通过窄查询与派生快照解决主瓶颈。
- **后端**：不改同步协议，不新增服务端统计表；本 change 主要是 iOS 本地性能与查询边界。

## Non-goals

- 不把 PR、周统计、动作曲线作为服务端权威数据持久化。
- 不改变 workout / workout_exercise / workout_set 的同步真相来源。
- 不恢复完整训练日历页面或重新设计历史页信息架构。
- 不引入 SQLite 直连读写作为常规产品路径；如需诊断可保留开发工具，但生产代码优先走 SwiftData/ModelContext。
- 不以“删除历史数据”作为性能解决方案。
