# Design — 历史训练性能优化

## 1. 问题模型

当前实现的根问题不是数据量绝对值，而是对象图边界失控：

```text
SwiftUI View
  @Query 所有 Workout
        │
        ├─ 每次 body 重算 filter/sort
        ├─ 每次访问 exercises 触发关系对象
        ├─ 每次访问 sets 触发孙节点对象
        └─ PR / 曲线 / 计划预填重复扫描
```

当前库实测：

| 实体 | 数量 |
|---|---:|
| `Workout` | 439 |
| `WorkoutExercise` | 1936 |
| `WorkoutSet` | 8188 |
| 最近 8 条涉及 set | 123 |
| 本周 set | 0 |

首页实际上只需要“本周 + 最近 8 条 + 一个 active session + 一个 active plan”，但代码路径会把近 8200 个 set 作为渲染输入。这与 Apple 对 Core Data 的性能建议相冲突：应根据展示需要收窄 predicate，避免不必要对象图膨胀；需要访问关系时应有明确的 batch/prefetch 策略，而不是在视图层隐式触发。

## 2. 设计原则

1. **原始记录仍是唯一事实源**：`Workout` 聚合树继续作为同步与重算真相。
2. **派生数据可删可重建**：任何缓存/索引均不参与云同步，不作为冲突合并依据。
3. **常规页面只消费窄输入**：Tab 根页、列表页、卡片行不得直接消费完整历史聚合树。
4. **钻取页才按需展开**：动作详情、训练详情可以加载相关子树，但必须按 exercise key / workout id / 时间范围限定。
5. **批量导入后可渐进恢复**：导入历史后允许后台重建 projection；UI 先显示最近记录与基础计数，重统计完成后刷新。

## 3. 派生层形态

新增一个 App 生命周期内的派生服务，命名暂定 `WorkoutHistoryStore`：

```swift
@MainActor
@Observable
final class WorkoutHistoryStore {
    var home: HomeWorkoutSnapshot
    var exercisePRs: [String: PRSummary]
    var latestSetsByPlanItemId: [UUID: [SetSnapshot]]
    var latestSetsByHistoryKey: [String: [SetSnapshot]]
    var profile: ProfileWorkoutSnapshot

    func refresh(reason: RefreshReason) async
    func invalidateAfterWorkoutChange(_ id: UUID)
}
```

快照均为纯值结构，避免把 `Workout` / `WorkoutExercise` / `WorkoutSet` 模型对象直接传入视图：

```swift
struct HomeWorkoutSnapshot {
    var currentWeekStats: WeeklyStats
    var recent: [WorkoutRowSummary]      // 最多 8 条
    var activePlanId: UUID?
    var prByWorkoutId: [UUID: PRBadge]
}

struct WorkoutRowSummary: Identifiable {
    var id: UUID
    var title: String
    var startedAt: Date
    var durationSec: TimeInterval?
    var exerciseCount: Int
    var setCount: Int
    var pr: PRBadge?
}
```

### 为什么先做内存 projection，不先落表

- 当前规模 8188 sets 一次扫描不大，真正问题是多页面、多次渲染重复扫描。
- 内存 projection 风险最低，不引入 SwiftData 迁移和缓存一致性问题。
- 若 1000/5000 workouts 压测仍慢，再追加本地持久化 materialized cache。

## 4. 刷新策略

```text
App 启动 / 登录完成
        │
        ▼
后台 refresh projection
        │
        ├─ 首页先展示轻量 skeleton/最近基础数据
        └─ projection 完成后刷新统计

训练完成 / 删除 / 同步 pull
        │
        ▼
标记 dirty
        │
        ├─ 小改动：局部增量更新
        └─ 大批量导入/首次构建：整库重建
```

MVP 可先实现整库重建，配合防抖：

- 同一 runloop / 500ms 内多次 SwiftData 变更合并为一次 refresh。
- refresh 在后台 `Task` 里构建纯值快照，最后回 MainActor 发布。
- UI 永远读上一次完成的快照，不在 `body` 内触发重建。

## 5. 页面改造边界

### 首页

当前：

```text
@Query all workouts
  ├─ finishedWorkouts
  ├─ stats
  ├─ prByWorkout
  ├─ recent prefix(8)
  └─ activePlan
```

目标：

```text
WorkoutListView
  ├─ active session: fetchLimit 1
  ├─ plans: 有效计划列表
  └─ historyStore.home
       ├─ currentWeekStats
       ├─ recent[0..<8]
       └─ prByWorkoutId
```

首页不再直接访问 `Workout.exercises.sets`。

### 动作库

- 列表行只读 `historyStore.exercisePRs[exercise.code]`。
- 不在 `rightArea` 中调用 `PRStats.maxWeightByKey(in: workouts)`。
- 动作详情按 exercise key 获取 `ExerciseHistorySnapshot`，支持 timeframe。

### 计划详情 / 开始训练

当前 `PlanPrescriptionPreview.make` 每个 item 多次扫描/排序 history。目标：

```text
PlanHistoryLookup
  latestByPlanItemId: [UUID: LatestExercisePerformance]
  latestByHistoryKey: [String: LatestExercisePerformance]
  skippedByPlanItemId: [UUID: Date]
```

构建一次，所有 item O(1) 查询。

### Profile

- 总训练数来自 `ProfileWorkoutSnapshot`。
- 不订阅全部已完成 `Workout`。

### WorkoutDetail

- 打开单条训练详情可查询该 workout 的子树。
- PR strip 优先使用 projection 里“本次是否 PR”的结果；若缺失则按 workout date 做一次窄重算，不订阅全部 finished workouts。

## 6. 同步与迁移减负

### `ExerciseHistoryMerge`

增加 UserDefaults 标记，例如：

```text
exerciseHistoryMerge.v1.completed = true
```

仅当标记不存在时 fetch 全部 `WorkoutExercise` 并执行幂等迁移。执行完成后写标记；后续启动跳过。

### `SyncEngine.syncWorkouts`

当前同步开始 `FetchDescriptor<Workout>()` 全量 fetch。目标拆分：

- push：只 fetch `syncStatus in pending*` 的 workouts。
- pull upsert：按 server/local id 建 lookup；可按 pulled ids 做 `IN` 查询，避免每个 dto 都全量 fetch。
- 同步完成后通知 `WorkoutHistoryStore` refresh；批量 pull 只触发一次。

## 7. 索引策略

短期优先级：

1. 窄查询和 projection。
2. 减少视图层对象图展开。
3. 必要时再加索引。

原因：

- 当前主瓶颈是 SwiftUI 重复扫描和关系对象展开，而不是 SQLite 查 439 行本身。
- 项目最低 iOS 17.4，SwiftData `#Index` 能力需确认部署兼容性，不能作为唯一解。
- 可先通过查询谓词、fetchLimit、纯值快照把卡顿降下来。

## 8. 验收指标

以真机或模拟器 Release 配置测量，至少覆盖当前库与压测库：

| 场景 | 当前库目标 | 1000 workouts 目标 | 5000 workouts 目标 |
|---|---:|---:|---:|
| 首页首次可交互 | < 200ms | < 300ms | < 500ms |
| Tab 切回首页 | < 100ms | < 150ms | < 250ms |
| 动作库切筛选 | < 100ms | < 150ms | < 250ms |
| 计划详情打开 | < 150ms | < 250ms | < 400ms |
| 结束训练后 PR 检测 | < 100ms | < 200ms | < 350ms |

若 5000 workouts 下首次 projection 重建超过目标，可接受后台构建，但主 UI 不得阻塞；完成后异步刷新。

## 9. 风险与取舍

- **缓存过期风险**：所有 projection 必须从单一 refresh 入口更新；训练完成、删除、同步 pull 后统一 invalidate。
- **语义漂移风险**：统计口径仍复用现有 `countsForStats` / `historyKey`，不要在 projection 里另写一套口径。
- **实现跨度风险**：分阶段落地，先首页和计划预填，后动作库/详情/Profile；每阶段都有可测收益。
- **持久化缓存诱惑**：不要第一步落表。只有压测证明内存 projection 不够时，再引入可重建本地 cache。
